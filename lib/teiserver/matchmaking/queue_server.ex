defmodule Teiserver.Matchmaking.QueueServer do
  @moduledoc """
  Very similar to Teiserver.Game.QueueWaitServer

  This process manages a given queue and attempt to match the members to play
  matches. Once player are matched, they are excluded from this queue and passed
  to a QueueRoomServer
  It also has some associated state for telemetry.
  """

  use GenServer
  require Logger
  alias Teiserver.Matchmaking.{QueueRegistry, PairingRoom}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Asset

  @typedoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @type member :: %{
          id: binary(),
          player_ids: [T.userid()],
          # maybe also add (aggregated) chevron if that's taking into account
          # map keyed by the rating type to {skill, uncertainty}
          # For example %{"duel" => {12, 3.2}}
          rating: %{String.t() => {integer(), integer()}},
          # aggregate of player to avoid for this member
          avoid: [T.userid()],
          joined_at: DateTime.t(),
          search_distance: non_neg_integer(),
          # how many ticks remaining before increasing the search distance
          increase_distance_after: non_neg_integer()
        }

  @type id :: String.t()

  @typedoc """
  Internal settings for the queue so it's easier to control the frequency of
  ticks and whatnot
  """
  @type settings :: %{
          tick_interval_ms: pos_integer() | :manual,
          max_distance: pos_integer(),
          pairing_timeout: timeout()
        }

  @typedoc """
  immutable specification of the queue
  """
  @type queue :: %{
          name: String.t(),
          team_size: pos_integer(),
          team_count: pos_integer(),
          ranked: boolean(),
          engines: [%{version: String.t()}],
          games: [%{spring_game: String.t()}],
          maps: [Teiserver.Asset.Map.t()]
        }

  @type state :: %{
          id: id(),
          queue: queue(),
          settings: settings(),
          members: [member()],
          # storing monitors to evict players that disconnect
          monitors: [{reference(), T.userid()}],
          # list of pairing rooms and which players are in it
          pairings: [{pid(), reference(), [T.userid()]}]

          # TODO: add some bits for telemetry (see QueueWaitServer) like avg
          # wait time and join count
        }

  @spec default_settings() :: settings()
  def default_settings() do
    %{tick_interval_ms: 5_000, max_distance: 15, pairing_timeout: 20_000}
  end

  @doc """
  Create a state for the GenServer, filling missing attributes with defaults
  """
  @spec init_state(%{
          required(:id) => id(),
          required(:name) => String.t(),
          required(:team_size) => pos_integer(),
          required(:team_count) => pos_integer(),
          optional(:engines) => [%{version: String.t()}],
          optional(:games) => [%{spring_game: String.t()}],
          optional(:maps) => [Teiserver.Asset.Map.t()],
          optional(:settings) => settings(),
          optional(:members) => [member()]
        }) :: state()
  def init_state(attrs) do
    %{
      id: attrs.id,
      queue: %{
        name: attrs.name,
        team_size: attrs.team_size,
        team_count: attrs.team_count,
        ranked: true,
        engines: Map.get(attrs, :engines, []),
        games: Map.get(attrs, :games, []),
        maps: Map.get(attrs, :maps, [])
      },
      settings: Map.merge(default_settings(), Map.get(attrs, :settings, %{})),
      members: Map.get(attrs, :members, []),
      monitors: [],
      pairings: []
    }
  end

  def via_tuple(queue_id) do
    QueueRegistry.via_tuple(queue_id)
  end

  def via_tuple(queue_id, queue) do
    QueueRegistry.via_tuple(queue_id, queue)
  end

  @type join_result ::
          :ok
          | {:error,
             :invalid_queue
             | :already_queued
             | :too_many_players
             | :missing_engines
             | :missing_games
             | :missing_maps}

  @doc """
  Join the specified queue
  """
  @spec join_queue(id(), member()) :: join_result()
  def join_queue(queue_id, member) do
    GenServer.call(via_tuple(queue_id), {:join_queue, member})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_queue}
  end

  @type leave_result :: :ok | {:error, {:not_queued, :invalid_queue}}

  @doc """
  Leave the specified queue. If the given player is a member of a party, then
  the entire party will leave the queue
  """
  @spec leave_queue(id(), T.userid()) :: leave_result()
  def leave_queue(queue_id, player_id) do
    GenServer.call(via_tuple(queue_id), {:leave_queue, player_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_queue}
  end

  @doc """
  When a pairing rooms times out or a player decline. Mark the players there
  as not pairing anymore, and should be removed from the queue.
  Rejoining should be done by the player themselves.
  """
  @spec disband_pairing(id(), pid()) :: :ok
  def disband_pairing(queue_id, room_pid) do
    GenServer.call(via_tuple(queue_id), {:disband_pairing, room_pid})
  catch
    # if the queue is gone for whatever reason, the pairing room should be
    # killed as well, and nothing will happen
    :exit, {:noproc, _} -> :ok
  end

  @spec start_link(state()) :: GenServer.on_start()
  def start_link(initial_state) do
    GenServer.start_link(__MODULE__, initial_state,
      name: via_tuple(initial_state.id, initial_state.queue)
    )
  end

  @impl true
  def init(state) do
    Logger.metadata(queue_id: state.id)

    if state.settings.tick_interval_ms != :manual do
      :timer.send_interval(state.settings.tick_interval_ms, :tick)
    end

    {:ok, state, {:continue, :init_engines}}
  end

  @impl true
  def handle_continue(:init_engines, state) do
    # TODO Get engines from somewhere else
    engines = state.queue.engines

    {:noreply, %{state | queue: Map.put(state.queue, :engines, engines)},
     {:continue, :init_games}}
  end

  @impl true
  def handle_continue(:init_games, state) do
    # TODO Get games from somewhere else
    games = state.queue.games

    {:noreply, %{state | queue: Map.put(state.queue, :games, games)}, {:continue, :init_maps}}
  end

  @impl true
  def handle_continue(:init_maps, state) do
    # Only get maps if the map list is empty
    maps = Asset.get_maps_for_queue(state.id)
    {:noreply, %{state | queue: Map.put(state.queue, :maps, maps)}}
  end

  @impl true
  def handle_call({:join_queue, new_member}, _from, state) do
    member_ids =
      Enum.flat_map(state.members, fn m -> m.player_ids end)
      |> MapSet.new()

    pairing_player_ids =
      for {_, _, player_ids} <- state.pairings, p_id <- player_ids do
        p_id
      end
      |> MapSet.new()

    new_ids = MapSet.new(new_member.player_ids)
    is_queuing = !MapSet.disjoint?(member_ids, new_ids)
    is_pairing = !MapSet.disjoint?(pairing_player_ids, new_ids)

    cond do
      Enum.count(new_member.player_ids) > state.queue.team_size ->
        {:reply, {:error, :too_many_players}, state}

      Enum.empty?(state.queue.engines) ->
        {:reply, {:error, :missing_engines}, state}

      Enum.empty?(state.queue.games) ->
        {:reply, {:error, :missing_games}, state}

      Enum.empty?(state.queue.maps) ->
        {:reply, {:error, :missing_maps}, state}

      !is_queuing && !is_pairing ->
        monitors =
          Enum.map(new_member.player_ids, fn user_id ->
            {Teiserver.Player.monitor_session(user_id), user_id}
          end)
          |> Enum.filter(fn {x, _} -> x != nil end)

        {:reply, :ok,
         %{state | members: [new_member | state.members], monitors: monitors ++ state.monitors}}

      true ->
        {:reply, {:error, :already_queued}, state}
    end
  end

  @impl true
  def handle_call({:leave_queue, player_id}, _from, state) do
    case remove_player(player_id, state) do
      :not_queued ->
        {:reply, {:error, :not_queued}, state}

      {:ok, state} ->
        {:reply, :ok, state}
    end
  end

  @doc """
  The pairing room is gone for one reason or another
  Rejoining the queue is not handled here, players will do that on their end
  """
  def handle_call({:disband_pairing, room_pid}, _from, state) do
    case Enum.split_with(state.pairings, fn {p, _, _} -> p == room_pid end) do
      {[{_, ref, player_ids}], rest} ->
        Process.demonitor(ref, [:flush])
        monitors = demonitor_players(player_ids, state.monitors)
        {:reply, :ok, %{state | pairings: rest, monitors: monitors}}

      _ ->
        {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, state) do
    case Enum.find(state.monitors, fn {mref, _} -> mref == ref end) do
      nil ->
        case(Enum.find(state.pairings, fn {_, mref, _} -> mref == ref end)) do
          nil ->
            {:noreply, state}

          {room_pid, _, player_ids} ->
            Logger.info(
              "pairing room went down #{inspect(room_pid)} with players: #{inspect(player_ids)}"
            )

            new_state =
              Enum.reduce(player_ids, state, fn p_id, st ->
                case remove_player(p_id, st) do
                  :not_queued -> st
                  {:ok, st} -> st
                end
              end)

            {:noreply, new_state}
        end

      {_ref, user_id} ->
        Logger.debug("Player #{user_id} went down, removing from queue #{state.id}")

        case remove_player(user_id, state) do
          :not_queued -> {:noreply, state}
          {:ok, state} -> {:noreply, state}
        end
    end
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      case match_members(state) do
        :no_match ->
          state

        {:match, matches} ->
          pairings =
            for teams <- matches do
              {:ok, pid} =
                PairingRoom.start(state.id, state.queue, teams, state.settings.pairing_timeout)

              ref = Process.monitor(pid)

              player_ids =
                for team <- teams, member <- team, player_id <- member.player_ids do
                  player_id
                end

              {pid, ref, player_ids}
            end

          matched_members =
            for teams <- matches, team <- teams, member <- team do
              member.id
            end
            |> MapSet.new()

          new_members =
            Enum.filter(state.members, fn m ->
              not Enum.member?(matched_members, m.id)
            end)

          state
          |> Map.put(:members, new_members)
          |> Map.update(:pairings, pairings, fn ps -> pairings ++ ps end)
      end

    {:noreply, new_state}
  end

  defp remove_player(player_id, state) do
    {to_remove, new_members} =
      Enum.split_with(state.members, fn member ->
        Enum.member?(member.player_ids, player_id)
      end)

    {pairing_to_remove, other_pairings} =
      Enum.split_with(state.pairings, fn {_, _, members} ->
        Enum.member?(members, player_id)
      end)

    case {to_remove, pairing_to_remove} do
      {[], []} ->
        :not_queued

      {[to_remove], _} ->
        monitors = demonitor_players(to_remove.player_ids, state.monitors)

        # TODO tachyon_mvp: need to let all the other players know that they are
        # being removed from the queue
        {:ok, %{state | members: new_members, monitors: monitors}}

      # there is no case with multiple member to remove since this is prevented when adding to a queue
      {_, [{room_pid, _, canceled_members}]} ->
        monitors = demonitor_players(canceled_members, state.monitors)
        PairingRoom.cancel(room_pid, player_id)
        {:ok, %{state | pairings: other_pairings, monitors: monitors}}
    end
  end

  @doc """
  This function shouldn't be public, but it's helpful for testing to export it
  Ultimately, as the complexity grows, it could be exported to another module
  dedicated to matching players, but for now this will do

  This returns a list of potential matches.
  A match is a list of teams, a team is a list of member
  """
  @spec match_members(state()) :: :no_match | {:match, [[[member()]]]}
  def match_members(state) do
    case greedy_match(state.queue.team_size, state.queue.team_count, state.members, [], []) do
      [] -> :no_match
      matches -> {:match, matches}
    end
  end

  defp greedy_match(team_size, team_count, members, current_team, matched) do
    # tachyon_mvp: this is a temporary algorithm
    # it only looks at the number of players to fill a team
    case members do
      [] ->
        Enum.chunk_every(matched, team_count, team_count, :discard)

      members ->
        current_size =
          current_team |> Enum.map(fn member -> Enum.count(member.player_ids) end) |> Enum.sum()

        case Enum.split_while(members, fn m ->
               Enum.count(m.player_ids) + current_size > team_size
             end) do
          # current team cannot be completed, discard it
          {_, []} ->
            greedy_match(team_size, team_count, members, [], matched)

          {too_big, [member | rest]} ->
            to_add = Enum.count(member.player_ids)
            rest = too_big ++ rest

            cond do
              current_size + to_add < team_size ->
                greedy_match(team_size, team_count, rest, [member | current_team], matched)

              current_size + to_add == team_size ->
                greedy_match(team_size, team_count, rest, [], [[member | current_team] | matched])
            end
        end
    end
  end

  defp demonitor_players(player_ids, monitors) do
    {refs_to_remove, refs_to_keep} =
      Enum.split_with(monitors, fn {_r, player_id} ->
        Enum.member?(player_ids, player_id)
      end)

    Enum.each(refs_to_remove, fn {r, _} -> Process.demonitor(r, [:flush]) end)
    refs_to_keep
  end
end
