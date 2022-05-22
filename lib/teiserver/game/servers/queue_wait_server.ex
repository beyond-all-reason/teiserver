defmodule Teiserver.Game.QueueWaitServer do
  use GenServer
  require Logger
  alias Teiserver.Data.Matchmaking
  alias Phoenix.PubSub
  alias Teiserver.{Telemetry}
  alias Teiserver.Data.Types, as: T

  @default_telemetry_interval 60_000
  @default_range_increase_interval 30_000
  @tick_interval 250
  @update_interval 2_500
  @max_range 5

  # Player item structure:
  # {userid, join_time, current_range, :user}

  # Party item structure
  # {party_id, join_time, current_range, :party}

  def handle_call({:add_user, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.wait_list, {userid, :user}) do
        true ->
          {:duplicate, state}

        false ->
          key = bucket_function(userid)
          player_item = {userid, System.system_time(:second), 0, :user}

          new_bucket = [player_item | Map.get(state.buckets, key, [])]
          new_buckets = Map.put(state.buckets, key, new_bucket)

          new_wait_list = [{userid, :user} | state.wait_list]

          new_state = %{
            state
            | buckets: new_buckets,
              wait_list: new_wait_list,
              skip: false,
              join_count: (state.join_count + 1)
          }

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_add_user, state.queue_id, userid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :join_queue, userid, state.queue_id}
          )

          {:ok, new_state}
      end

    {:reply, resp, new_state}
  end

  def handle_call({:remove_user, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.wait_list, {userid, :user}) do
        true ->
          new_state = remove_user(userid, state)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_remove_user, state.queue_id, userid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :leave_queue, userid, state.queue_id}
          )

          {:ok, %{new_state | leave_count: (state.leave_count - 1)}}

        false ->
          {:missing, state}
      end

    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      mean_wait_time: state.mean_wait_time,
      member_count: Enum.count(state.wait_list)
    }

    {:reply, resp, state}
  end

  def handle_cast({:re_add_users, player_list}, state) do
    # First we ignore those already added
    new_state = player_list
      |> Enum.reject(fn {userid, _, _, type} -> Enum.member?(state.wait_list, {userid, type}) end)
      |> Enum.reduce(state, fn (player_item = {itemid, _, _, type}, acc) ->
        key = bucket_function(itemid)

        new_bucket = [player_item | Map.get(acc.buckets, key, [])]
        new_buckets = Map.put(acc.buckets, key, new_bucket)

        new_wait_list = [{itemid, type} | acc.wait_list]

        new_state = %{
          acc
          | buckets: new_buckets,
            wait_list: new_wait_list,
            skip: false
        }

        if type == :user do
          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{acc.queue_id}",
            {:queue_wait, :queue_add_user, acc.queue_id, itemid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{itemid}",
            {:client_action, :join_queue, itemid, acc.queue_id}
          )
        end

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
    Telemetry.cast_to_server({:matchmaking_update, state.queue_id, %{
      mean_wait_time: calculate_mean_wait_time(state),
      member_count: Enum.count(state.wait_list),
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
      {:queue_periodic_update, state.queue_id, Enum.count(state.wait_list), mean_wait_time}
    )
    {:noreply, %{state | mean_wait_time: mean_wait_time}}
  end

  def handle_info(:tick, %{skip: true} = state) do
    :timer.send_after(@tick_interval, :tick)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    matches = state.buckets
      |> Enum.map(fn {key, players} ->
        players
          |> Enum.map(fn {userid, time, current_range, type} ->
            {best_match, _distance} = find_matches(userid, key, current_range, state.buckets)
              |> Enum.sort_by(fn {_data, distance} -> distance end)
              |> hd_or_x({nil, nil})

            {{userid, time, current_range, type}, best_match}
          end)
      end)
      |> List.flatten
      |> Enum.filter(fn {_userid_type, match} -> match != nil end)
      |> Enum.map(fn match ->
        team_list = case match do
          {m1, m2} -> [m1, m2]
        end
        Matchmaking.create_match(team_list, state.queue_id)
      end)

    {new_buckets, new_wait_list, wait_times} = case matches do
      [] ->
        {state.buckets, state.wait_list, []}

      _ ->
        # Teams will be: [{id, time, range, type}]
        matched_teams = matches
          |> Enum.map(fn {_pid, _match_id, teams} -> teams end)
          |> List.flatten

        new_buckets = state.buckets
          |> Map.new(fn {key, members} ->
            new_members = members |>
              Enum.reject(fn team -> Enum.member?(matched_teams, team) end)

            {key, new_members}
          end)

        waits_to_remove = matched_teams
          |> Enum.map(fn {id, _time, _range, type} -> {id, type} end)

        new_wait_list = state.wait_list
          |> Enum.reject(fn u -> Enum.member?(waits_to_remove, u) end)

        wait_times = matched_teams
          |> Enum.map(fn {_id, time, _range, _type} -> System.system_time(:second) - time end)

        {new_buckets, new_wait_list, wait_times}
    end

    :timer.send_after(@tick_interval, :tick)
    {:noreply, %{state |
      buckets: new_buckets,
      wait_list: new_wait_list,
      found_match_count: (state.found_match_count + Enum.count(matches)),
      recent_wait_times: state.recent_wait_times ++ wait_times
    }}
  end

  def handle_info({:update, :settings, new_list}, state),
    do: {:noreply, %{state | settings: new_list}}

  def handle_info({:update, :map_list, new_list}, state),
    do: {:noreply, %{state | map_list: new_list}}

  @spec find_matches(T.userid(), non_neg_integer(), non_neg_integer(), map()) :: [{T.userid(), non_neg_integer()}]
  defp find_matches(userid, key, current_range, buckets) do
    buckets
      |> Enum.filter(fn {inner_key, _players} ->
        abs(key - inner_key) <= current_range and inner_key <= key
      end)
      |> Enum.map(fn {inner_key, players} ->
        players
          |> Enum.filter(fn {player_id, _time, player_range, _type} ->
            (abs(key - inner_key) <= player_range) and (player_id != userid)
          end)
          |> Enum.map(fn {player_id, time, player_range, type} ->
            {{player_id, time, player_range, type}, abs(key - inner_key)}
          end)
      end)
      |> List.flatten
  end

  # Used to remove players from all aspects of the queue, either because
  # they left or their game started
  @spec remove_user(T.userid(), Map.t()) :: Map.t()
  defp remove_user(userid, state) do
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
      map_list: db_queue.map_list |> Enum.map(fn m -> String.trim(m) end),
      settings: db_queue.settings,
    })
  end

  @spec bucket_function(T.userid()) :: non_neg_integer()
  defp bucket_function(user_id) do
    rem(user_id, 2)
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
        wait_list: [],
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
