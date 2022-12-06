defmodule Teiserver.Game.QueueWaitServer do
  @moduledoc """
  This is the server used to match players for a battle before passing them off
  to a QueueMatchServer.
  """

  use GenServer
  require Logger
  alias Teiserver.Data.{Matchmaking, QueueGroup}
  alias Phoenix.PubSub
  alias Teiserver.{Telemetry}
  alias Teiserver.Data.Types, as: T

  @default_telemetry_interval 60_000
  @default_range_increase_interval 30_000
  @tick_interval 250
  @update_interval 2_500
  @max_range 5

  def handle_call({:add_group, %QueueGroup{members: _, rating: _} = group}, _from, state) do
    {resp, new_state} =
      case Map.has_key?(state.groups_map, group.id) do
        true ->
          {:duplicate, state}

        false ->
          bucket_key = bucket_function(group)
          new_group = %{group | bucket: bucket_key}
          new_groups_map = Map.put(state.groups_map, group.id, new_group)

          new_bucket = [group.id | Map.get(state.buckets, bucket_key, [])]
          new_buckets = Map.put(state.buckets, bucket_key, new_bucket)

          new_state = %{
            state
            | buckets: new_buckets,
              groups_map: new_groups_map,
              skip: false,
              join_count: (state.join_count + 1)
          }

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_add_user, state.queue_id, group.id}
          )

          group.members
          |> Enum.each(fn userid ->
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_client_messages:#{userid}",
              %{
                channel: "teiserver_client_messages:#{userid}",
                event: :matchmaking,
                sub_event: :joined_queue,
                queue_id: state.queue_id
              }
            )
          end)

          {:ok, new_state}
      end

    {:reply, resp, new_state}
  end

  def handle_call({:remove_group, group_id}, _from, state) do
    {resp, new_state} =
      case Map.has_key?(state.groups_map, group_id) do
        true ->
          new_state = remove_group(group_id, state)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_remove_group, state.queue_id, group_id}
          )

          state.group_map[group_id]
          |> Enum.each(fn userid ->
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_client_messages:#{userid}",
              %{
                channel: "teiserver_client_messages:#{userid}",
                event: :matchmaking,
                sub_event: :left_queue,
                queue_id: state.queue_id
              }
            )
          end)

          {:ok, %{new_state | leave_count: (state.leave_count + 1)}}

        false ->
          {:missing, state}
      end

    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      mean_wait_time: state.mean_wait_time,
      member_count: Enum.count(state.groups_map)
    }

    {:reply, resp, state}
  end

  def handle_cast({:re_add_users, groups}, state) do
    # First we ignore those already added
    new_state = groups
      |> Enum.reject(fn group -> Enum.member?(state.groups_map, group.id) end)
      |> Enum.reduce(state, fn (group, acc) ->
        key = bucket_function(group)

        new_bucket = [group | Map.get(acc.buckets, key, [])]
        new_buckets = Map.put(acc.buckets, key, new_bucket)

        new_groups_map = Map.put(acc.groups_map, group.id, group)

        new_state = %{
          acc
          | buckets: new_buckets,
            groups_map: new_groups_map,
            skip: false
        }


        PubSub.broadcast(
          Central.PubSub,
          "teiserver_queue_wait:#{state.queue_id}",
          {:queue_wait, :queue_add_user, state.queue_id, group.id}
        )

        groups
        |> Enum.each(fn group ->
          group.members
          |> Enum.each(fn userid ->
            PubSub.broadcast(
              Central.PubSub,
              "teiserver_client_messages:#{userid}",
              %{
                channel: "teiserver_client_messages:#{userid}",
                event: :matchmaking,
                sub_event: :joined_queue,
                queue_id: state.queue_id
              }
            )
          end)
        end)

        new_state
      end)

    {:noreply, new_state}
  end

  def handle_info({:refresh_from_db, db_queue}, state) do
    update_state_from_db(state, db_queue)
  end

  def handle_info(:increase_range, state) do
    new_buckets = state.buckets
      |> Map.new(fn {key, players} ->
        new_players = players
          |> Enum.map(fn {userid, join_time, current_range, type} ->
            {userid, join_time, min(current_range + 1, @max_range), type}
          end)

        {key, new_players}
      end)

    {:noreply, %{state | buckets: new_buckets}}
  end

  def handle_info(:telemetry_tick, state) do
    member_count = state.groups_map
      |> Map.values
      |> Map.get(:count)
      |> Enum.sum

    Telemetry.cast_to_server({:matchmaking_update, state.queue_id, %{
      mean_wait_time: calculate_mean_wait_time(state),
      member_count: member_count,
      join_count: state.join_count,
      leave_count: state.leave_count,
      found_match_count: state.found_match_count
    }})

    {:noreply, %{state |
      recent_wait_times: [],
      old_wait_times: state.recent_wait_times,
      join_count: 0,
      leave_count: 0,
      found_match_count: 0
    }}
  end

  def handle_info(:broadcast_update, state) do
    mean_wait_time = calculate_mean_wait_time(state)

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_queue_all_queues",
      {:queue_periodic_update, state.queue_id, Enum.count(state.groups_map), mean_wait_time}
    )
    {:noreply, %{state | mean_wait_time: mean_wait_time}}
  end

  def handle_info(:tick, %{skip: true} = state) do
    :timer.send_after(@tick_interval, :tick)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    {matches, new_buckets, new_groups_map, wait_times} = main_loop_search(state)

    :timer.send_after(@tick_interval, :tick)
    {:noreply, %{state |
      buckets: new_buckets,
      groups_map: new_groups_map,
      found_match_count: (state.found_match_count + Enum.count(matches)),
      recent_wait_times: state.recent_wait_times ++ wait_times
    }}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}


  @spec find_matches(map(), [non_neg_integer()]) :: list()
  defp find_matches(state, groups) do
    user_count = groups
      |> Enum.map(fn group_id -> state.group_map[group_id].count end)
      |> Enum.sum

    if user_count >= state.players_needed do
      IO.puts ""
      IO.inspect groups
      IO.puts ""

      identify_best_match()
    else
      IO.puts ""
      IO.inspect state.group_map
      IO.inspect {user_count, state.players_needed}
      IO.puts ""

      []
    end
  end

  # @spec find_matches(T.userid() | String.t(), non_neg_integer(), non_neg_integer(), map()) :: [{T.userid(), non_neg_integer()}]
  # defp find_matches(group_id, key, current_range, buckets) do
  #   buckets
  #     |> Enum.filter(fn {inner_key, _players} ->
  #       abs(key - inner_key) <= current_range and inner_key <= key
  #     end)
  #     |> Enum.map(fn {inner_key, players} ->
  #       players
  #         |> Enum.filter(fn {group_id, _time, player_range, _type} ->
  #           (abs(key - inner_key) <= player_range) and (group_id != userid)
  #         end)
  #         |> Enum.map(fn {group_id, time, player_range, type} ->
  #           {{group_id, time, player_range, type}, abs(key - inner_key)}
  #         end)
  #     end)
  #     |> List.flatten
  # end

  defp identify_best_match() do

  end

  @spec main_loop_search(map()) :: {list(), map(), map(), list()}
  defp main_loop_search(state) do
    # {matches, state.buckets, state.groups_map, []}
    {[], state.buckets, state.groups_map, []}
  end

  # defp old_main_loop_search(state) do
  #   matches = state.buckets
  #   |> Stream.map(fn {bucket_key, groups} ->
  #     groups
  #     |> Enum.map(fn group ->
  #       {best_match, _distance} = find_matches(group.id, key, current_range, state.buckets)
  #         |> Enum.sort_by(fn {_data, distance} -> distance end)
  #         |> hd_or_x({nil, nil})

  #       # If both teams are in the same bucket we can get a double-match
  #       # event where it tries to create A-B and B-A
  #       # to solve this we sort them based on their
  #       # join time and call Enum.uniq later
  #       if best_match != nil do
  #         {_, best_time, _, _} = best_match

  #         if best_time < time do
  #           {best_match, {userid, time, current_range, type}}
  #         else
  #           {{userid, time, current_range, type}, best_match}
  #         end
  #       else
  #         {{userid, time, current_range, type}, best_match}
  #       end
  #     end)
  #   end)
  #   |> List.flatten
  #   |> Enum.uniq
  #   |> Enum.filter(fn {_userid_type, match} -> match != nil end)
  #   |> Enum.map(fn match ->
  #     team_list = case match do
  #       {m1, m2} -> [m1, m2]
  #     end

  #     team_list
  #       |> Enum.each(fn
  #         {userid, _, _, :user} ->
  #           PubSub.broadcast(
  #             Central.PubSub,
  #             "teiserver_queue_wait:#{state.queue_id}",
  #             {:queue_wait, :queue_remove_group, state.queue_id, userid}
  #           )
  #         _ ->
  #           :ok
  #       end)

  #     Matchmaking.create_match(team_list, state.queue_id)
  #   end)

  #   {new_buckets, new_groups_map, wait_times} = case matches do
  #     [] ->
  #       {state.buckets, state.groups_map, []}

  #     _ ->
  #       # Teams will be: [{id, time, range, type}]
  #       matched_teams = matches
  #         |> Enum.map(fn {_pid, _match_id, teams} -> teams end)
  #         |> List.flatten

  #       new_buckets = state.buckets
  #         |> Map.new(fn {key, members} ->
  #           new_members = members |>
  #             Enum.reject(fn team -> Enum.member?(matched_teams, team) end)

  #           {key, new_members}
  #         end)

  #       waits_to_remove = matched_teams
  #         |> Enum.map(fn {id, _time, _range, type} -> {id, type} end)

  #       new_wait_list = state.wait_list
  #         |> Enum.reject(fn u -> Enum.member?(waits_to_remove, u) end)

  #       wait_times = matched_teams
  #         |> Enum.map(fn {_id, time, _range, _type} -> System.system_time(:second) - time end)

  #       {new_buckets, new_wait_list, wait_times}
  #   end

  #   {matches, new_buckets, new_wait_list, wait_times}
  # end

  # Used to remove players from all aspects of the queue, either because
  # they left or their game started
  @spec remove_group(T.userid(), Map.t()) :: Map.t()
  defp remove_group(userid, state) do
    key = bucket_function(userid)

    new_bucket = state.buckets[key]
      |> Enum.reject(fn {u, _, _, :user} -> userid == u end)
    new_buckets = Map.put(state.buckets, key, new_bucket)

    new_wait_list = state.wait_list |> List.delete({userid, :user})

    %{state |
      buckets: new_buckets,
      wait_list: new_wait_list
    }
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  defp update_state_from_db(state, db_queue) do
    Map.merge(state, %{
      id: db_queue.id,
      team_size: db_queue.team_size,
      team_count: db_queue.team_count,
      players_needed: (db_queue.team_size * db_queue.team_count),
      map_list: db_queue.map_list |> Enum.map(fn m -> String.trim(m) end),
      settings: db_queue.settings,
    })
  end

  @spec bucket_function(QueueGroup.t()) :: non_neg_integer()
  defp bucket_function(%QueueGroup{rating: rating}) do
    rating
      |> round
      |> max(1)
  end

  defp hd_or_x([], x), do: x
  defp hd_or_x([x | _], _x), do: x

  defp calculate_mean_wait_time(state) do
    wait_times = state.recent_wait_times ++ state.old_wait_times

    Enum.sum(wait_times)/(Enum.count(wait_times) + 1)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    :timer.send_interval(@default_telemetry_interval, self(), :telemetry_tick)
    :timer.send_interval(@default_range_increase_interval, self(), :increase_range)
    :timer.send_interval(@update_interval, self(), :broadcast_update)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "QueueWaitServer:#{opts.queue.id}",
      opts.queue.id
    )

    state = update_state_from_db(%{
      buckets: %{},
      groups_map: %{},

      skip: false,
      queue_id: opts.queue.id,

      # Telemetry related
      mean_wait_time: 0,
      recent_wait_times: [],
      old_wait_times: [],
      join_count: 0,
      leave_count: 0,
      found_match_count: 0
    }, opts.queue)

    send(self(), :tick)

    {:ok, state}
  end
end
