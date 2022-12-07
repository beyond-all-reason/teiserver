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
    new_state = case main_loop_search(state) do
      nil ->
        state

      {selected_groups, new_buckets, new_groups_map} ->
        wait_times = selected_groups
          |> Enum.map(fn g -> System.system_time(:second) - g.join_time end)

        %{state |
          buckets: new_buckets,
          groups_map: new_groups_map,
          found_match_count: (state.found_match_count + 1),
          recent_wait_times: state.recent_wait_times ++ wait_times
        }
    end

    :timer.send_after(@tick_interval, :tick)
    {:noreply, state}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}


  @spec find_matches_in_bucket(map(), [non_neg_integer()]) :: list()
  defp find_matches_in_bucket(state, group_id_list) do
    group_list = group_id_list
      |> Enum.map(fn group_id -> state.groups_map[group_id] end)

    user_count = group_list
      |> Enum.map(fn group -> group.count end)
      |> Enum.sum

    if user_count >= state.players_needed do
      select_groups_for_balance(state, group_list)
    else
      nil
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

  # TODO: Actually identify which groups are closest to each other?
  @spec select_groups_for_balance(map(), [QueueGroup.t()]) :: [QueueGroup.t()]
  defp select_groups_for_balance(state, group_list) do
    # We just need to find N teams of S people, then we balance it
    # largest groups first

    # First we sort the group list, should be biggest groups first
    group_list = group_list
      |> Enum.sort_by(fn group -> group.count end, &>=/2)

    # Now we iterate through each team_id and pick groups
    # it doesn't matter which team they are picked for as we'll be balancing it later
    {picks, _} = 1..state.team_count
      |> Enum.map_reduce(group_list, fn (team_id, remaining_groups) ->
        # Grab the first groups we find from the list as long as they match the required size
        picked = pick_groups_from_list_to_size(remaining_groups, state.team_size, [])

        # IO.puts ""
        # IO.inspect picked, label: "#{team_id} picked"
        # IO.puts ""

        # TODO: Handle :failure, also find a situation where it would happen?
        if picked == :failure do
          Logger.error("Error at: #{__ENV__.file}:#{__ENV__.line}\npicked == :failure")
          Logger.error("group_list: #{inspect group_list}")
          Logger.error("team_count: #{inspect state.team_count}, team_id: #{inspect team_id}, remaining_groups: #{inspect remaining_groups}")
        end

        # Convert the groups to ids
        picked_ids = picked |> Enum.map(fn g -> g.id end)

        # Strip out from the list any groups we've picked
        new_remaining = remaining_groups
          |> Enum.reject(fn g -> Enum.member?(picked_ids, g.id) end)

        # map and reduce
        {picked, new_remaining}
      end)

    # Picks will now be a list of groups picked for balancing, we don't care which
    # team they were picked as a part of since we don't handle balance here
    List.flatten(picks)
  end

  # Recursively goes through a list and gets the first groups that match it's criteria of size
  defp pick_groups_from_list_to_size(_, 0, acc), do: acc
  defp pick_groups_from_list_to_size([], _, _), do: :failure

  defp pick_groups_from_list_to_size([first_group | remaining_list], target_size, acc) do
    if first_group.count <= target_size do
      new_acc = [first_group | acc]
      new_target = target_size - first_group.count

      pick_groups_from_list_to_size(remaining_list, new_target, new_acc)
    else
      pick_groups_from_list_to_size(remaining_list, target_size, acc)
    end
  end

  # Returns a list of the groups selected for the next match (empty list if no match found)
  # the new buckets and the new groups_map
  @spec main_loop_search(map()) :: {list(), map(), map()} | nil
  defp main_loop_search(state) do
    IO.puts "state.buckets"
    IO.inspect state.buckets
    IO.puts ""

    selected_groups = state.buckets
      |> Stream.filter(fn {_bucket_key, group_list} ->
        Enum.count(group_list) >= state.players_needed
      end)
      |> Stream.map(fn {_bucket_key, group_list} ->
        matches = find_matches_in_bucket(state, group_list)
      end)
      |> Stream.reject(&(&1 == nil))
      |> Stream.take(1)
      |> Enum.to_list
      |> List.flatten

    if Enum.empty?(selected_groups) do
      nil
    else
      selected_ids = selected_groups
        |> Enum.map(fn g -> g.id end)

      # Drop the selected ids from any bucket values
      new_buckets = state.buckets
        |> Map.new(fn {key, bucket_list} ->
          {key, Enum.reject(bucket_list, fn g_id -> Enum.member?(selected_ids, g_id) end)}
        end)
        |> Map.filter(fn {_, bucket_list} -> not Enum.empty?(bucket_list) end)

      # Drop the groups from the groups_map too
      new_groups_map = Map.drop(state.groups_map, selected_ids)

      IO.puts "New values"
      IO.inspect new_buckets
      IO.inspect new_groups_map
      IO.puts ""

      {selected_groups, new_buckets, new_groups_map}
    end
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
