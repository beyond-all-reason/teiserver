defmodule Teiserver.Game.QueueWaitServer do
  use GenServer
  require Logger
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  alias Phoenix.PubSub
  alias Teiserver.{Coordinator, Client, Telemetry}
  alias Teiserver.Data.Types, as: T

  @default_telemetry_interval 10_000
  @default_range_increase_interval 30_000
  @max_range 5

  # Player item structure:
  # {userid, join_time, current_range, :user}

  # Party item structure
  # {party_id, join_time, current_range, :party}

  def handle_call({:add_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.player_list, userid) do
        true ->
          {:duplicate, state}

        false ->
          key = bucket_function(userid)
          player_item = {userid, :erlang.system_time(:seconds), 0, :user}

          new_bucket = [player_item | Map.get(state.buckets, key, [])]
          new_buckets = Map.put(state.buckets, key, new_bucket)

          new_player_list = [userid | state.player_list]

          new_state = %{
            state
            | buckets: new_buckets,
              player_list: new_player_list,
              player_count: Enum.count(new_player_list),
              skip: false
          }

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_add_player, state.queue_id, userid}
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

  def handle_call({:remove_player, userid}, _from, state) when is_integer(userid) do
    {resp, new_state} =
      case Enum.member?(state.player_list, userid) do
        true ->
          new_state = remove_player(state, userid)

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_queue_wait:#{state.queue_id}",
            {:queue_wait, :queue_remove_player, state.queue_id, userid}
          )

          PubSub.broadcast(
            Central.PubSub,
            "teiserver_client_action_updates:#{userid}",
            {:client_action, :leave_queue, userid, state.queue_id}
          )

          {:ok, new_state}

        false ->
          {:missing, state}
      end

    {:reply, resp, new_state}
  end

  def handle_call(:get_info, _from, state) do
    resp = %{
      last_wait_time: state.last_wait_time,
      player_count: state.player_count
    }

    {:reply, resp, state}
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
      last_wait_time: state.last_wait_time,
      player_count: state.player_count
    }})

    {:noreply, state}
  end

  def handle_info(:tick, %{skip: true} = state) do
    :timer.send_after(250, :tick)
    {:noreply, state}
  end

  def handle_info(:tick, state) do
    matches = state.buckets
      |> Enum.map(fn {key, players} ->
        players
          |> Enum.map(fn {userid, _time, current_range, _type} ->
            best_match = find_matches(userid, key, current_range, state.buckets)
              |> Enum.sort_by(fn {_userid, distance} -> distance end)
              |> hd_or_x(nil)

            {userid, best_match}
          end)
      end)
      |> List.flatten
      |> Enum.filter(fn {_userid, match} -> match != nil end)
      |> Enum.map(fn {userid, {matchid, _}} -> [userid, matchid] end)
      |> Enum.map(fn match ->
        create_match(match, state)
      end)

    {new_buckets, new_player_list} = case matches do
      [] ->
        {state.buckets, state.player_list}

      _ ->
        userids = matches
          |> Enum.map(fn {_pid, ids} -> ids end)
          |> List.flatten

        new_buckets = state.buckets
          |> Map.new(fn {key, members} ->
            new_members = members |>
              Enum.reject(fn {mem, _time, _range, _type} -> Enum.member?(userids, mem) end)

            {key, new_members}
          end)

        new_player_list = state.player_list
          |> Enum.reject(fn u -> Enum.member?(userids, u) end)

        {new_buckets, new_player_list}
    end

    :timer.send_after(250, :tick)
    {:noreply, %{state |
      buckets: new_buckets,
      player_list: new_player_list,
      player_count: Enum.count(new_player_list)
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
          |> Enum.map(fn {player_id, _time, _player_range, _type} ->
            {player_id, abs(key - inner_key)}
          end)
      end)
      |> List.flatten
  end

  @spec create_match(list(), map()) :: {pid, list()}
  defp create_match(members, state) do
    pid = Matchmaking.add_match_server(state.queue_id, members)
    {pid, members}
  end

  # Used to remove players from all aspects of the queue, either because
  # they left or their game started
  @spec remove_player(Map.t(), T.userid()) :: Map.t()
  defp remove_player(state, userid) do
    key = bucket_function(userid)

    new_bucket = state.buckets[key] |> List.delete(userid)
    new_buckets = Map.put(state.buckets, key, new_bucket)

    new_player_list = state.player_list |> List.delete(userid)

    %{state |
      buckets: new_buckets,
      player_list: new_player_list,
      player_count: Enum.count(new_player_list)
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

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    :timer.send_interval(@default_telemetry_interval, self(), :telemetry_tick)
    :timer.send_interval(@default_range_increase_interval, self(), :increase_range)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "QueueWaitServer:#{opts.queue.id}",
      opts.queue.id
    )

    state = update_state_from_db(%{
       buckets: %{},
       player_list: [],
       player_count: 0,
       last_wait_time: 0,
       skip: false,
       queue_id: opts.queue.id
     }, opts.queue)

     send(self(), :tick)

    {:ok, state}
  end
end
