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
  alias Teiserver.Battle.MatchLib
  alias Teiserver.Matchmaking.{QueueRegistry, PairingRoom}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Asset
  alias Teiserver.Party
  alias Teiserver.Player
  alias Teiserver.Helpers.MonitorCollection, as: MC
  alias Teiserver.Matchmaking.Member
  alias Teiserver.Matchmaking.Algo

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
  what algorithm this queue should use to put players/party together?
  """
  @type algo :: {module(), term()}

  @typedoc """
  immutable specification of the queue
  """
  @type queue :: %{
          name: String.t(),
          team_size: pos_integer(),
          team_count: pos_integer(),
          ranked: boolean(),
          algo: algo(),
          engines: [%{version: String.t()}],
          games: [%{spring_game: String.t()}],
          maps: [Teiserver.Asset.Map.t()]
        }

  @type state :: %{
          id: id(),
          queue: queue(),
          settings: settings(),
          members: [Member.t()],
          # storing monitors to evict players that disconnect
          # also store pairing rooms
          monitors: MC.t(),
          # list of pairing rooms and which players are in it
          pairings: [{pid(), [T.userid()]}],

          # a buffer when a party is joining, to make sure all player are indeed
          # committed to joining this queue
          pending_parties: %{
            Party.id() => %{waiting_for: [T.userid()], joined: [T.userid()], tref: :timer.tref()}
          }

          # TODO: add some bits for telemetry (see QueueWaitServer) like avg
          # wait time and join count
        }

  @type cancelled_reason ::
          :intentional | {:server_error, term()} | :party_user_left | :ready_timeout

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
          optional(:members) => [Member.t()],
          optional(:algo) => :ignore_os | :bruteforce_filter
        }) :: state()
  def init_state(attrs) do
    alg_module =
      case Map.get(attrs, :algo, :ignore_os) do
        :ignore_os -> Algo.IgnoreOs
        :bruteforce_filter -> Algo.BruteforceFilter
      end

    alg_state = apply(alg_module, :init, [attrs.team_size, attrs.team_count])

    %{
      id: attrs.id,
      queue: %{
        name: attrs.name,
        team_size: attrs.team_size,
        team_count: attrs.team_count,
        algo: {alg_module, alg_state},
        ranked: true,
        engines: Map.get(attrs, :engines, []),
        games: Map.get(attrs, :games, []),
        maps: Map.get(attrs, :maps, [])
      },
      settings: Map.merge(default_settings(), Map.get(attrs, :settings, %{})),
      members: Map.get(attrs, :members, []),
      monitors: MC.new(),
      pairings: [],
      pending_parties: %{}
    }
  end

  def via_tuple(queue_id) do
    QueueRegistry.via_tuple(queue_id)
  end

  def via_tuple(queue_id, queue) do
    QueueRegistry.via_tuple(queue_id, queue)
  end

  @type join_error ::
          {:error,
           :invalid_queue
           | :already_queued
           | :too_many_players
           | :missing_engines
           | :missing_games
           | :missing_maps
           | :party_too_big}
  @type join_result :: {:ok, queue_pid :: pid()} | join_error()

  @doc """
  Join the specified queue
  """
  @spec join_queue(id(), T.userid(), Party.id() | nil) :: join_result()
  def join_queue(queue_id, user_id, party_id) do
    if party_id == nil,
      do: GenServer.call(via_tuple(queue_id), {:join_queue, user_id}),
      else: GenServer.call(via_tuple(queue_id), {:join_queue, user_id, party_id})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_queue}
  end

  @doc """
  Creates a "slot" in the queue for the party member to then join the queue.
  All members must then call party_member_join_queue within a short time
  or the operation is cancelled and all players already joined are kicked out
  of the queue.
  This is to ensure all party member are there as a unit and avoid race where
  a member could disconnect in the middle of the joining process.
  """
  @spec party_join_queue(id(), Party.id(), [%{id: T.userid()}]) ::
          {:ok, queue_pid :: pid()} | {:error, reason :: term()}
  def party_join_queue(queue_id, party_id, players) do
    GenServer.call(via_tuple(queue_id), {:party_join_queue, party_id, players})
  catch
    :exit, {:noproc, _} -> {:no, :invalid_queue}
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
    Logger.metadata(actor_type: :mm_queue, actor_id: state.id)

    if state.settings.tick_interval_ms != :manual do
      :timer.send_interval(state.settings.tick_interval_ms, :tick)
    end

    {:ok, state, {:continue, :init_engines_games_maps}}
  end

  @impl true
  def handle_continue(:init_engines_games_maps, state) do
    engines = state.queue.engines
    games = state.queue.games
    maps = Asset.get_maps_for_queue(state.id)

    queue = %{state.queue | engines: engines, games: games, maps: maps}

    {:noreply, %{state | queue: queue}}
  end

  @impl true
  def handle_call({:join_queue, player_id}, _from, state) do
    case member_can_join_queue?([player_id], state) do
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      :ok ->
        game_type = MatchLib.game_type(state.queue.team_size, state.queue.team_count)
        new_member = Member.new([player_id], game_type)
        new_state = add_member_to_queue(state, new_member)
        {:reply, {:ok, self()}, new_state}
    end
  end

  @impl true
  def handle_call({:join_queue, player_id, party_id}, _from, state) do
    game_type = MatchLib.game_type(state.queue.team_size, state.queue.team_count)

    with :ok <- member_can_join_queue?([player_id], state),
         pending when pending != nil <- Map.get(state.pending_parties, party_id) do
      case Enum.split_with(pending.waiting_for, &(&1 == player_id)) do
        {[], _} ->
          {:reply, {:error, :invalid_queue}, state}

        {[_], []} ->
          member = Member.new([player_id | pending.joined], game_type)

          :timer.cancel(pending.tref)

          new_state =
            state
            |> Map.update!(:pending_parties, &Map.delete(&1, party_id))
            |> add_member_to_queue(member)

          Logger.info("Party #{party_id} with members #{inspect(member.player_ids)} joined queue")

          {:reply, {:ok, self()}, new_state}

        {[_], rest} ->
          pending =
            pending
            |> Map.replace!(:waiting_for, rest)
            |> Map.update!(:joined, fn js -> [player_id | js] end)

          new_state =
            state
            |> put_in([:pending_parties, party_id], pending)

          {:reply, {:ok, self()}, new_state}
      end
    else
      {:error, reason} ->
        {:reply, {:error, reason}, state}

      nil ->
        {:reply, {:error, :invalid_party}, state}
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
    case Enum.split_with(state.pairings, fn {p, _} -> p == room_pid end) do
      {[{_, player_ids}], rest} ->
        monitors =
          demonitor_players(player_ids, state.monitors)
          |> MC.demonitor_by_val({:room, room_pid, player_ids})

        {:reply, :ok, %{state | pairings: rest, monitors: monitors}}

      _ ->
        {:reply, :ok, state}
    end
  end

  def handle_call({:party_join_queue, party_id, players}, _from, state) do
    cond do
      length(players) > state.queue.team_size ->
        {:reply, {:error, :party_too_big}, state}

      party_id in state.pending_parties ->
        {:reply, {:error, :already_joined}, state}

      true ->
        # don't bother creating monitors for the players or the party
        # since the entry gets removed after a short timeout.
        state =
          Map.update!(state, :pending_parties, fn p ->
            ids = Enum.map(players, fn player -> player.id end)
            tref = :timer.send_after(5000, {:cancel_party, party_id})
            Map.put(p, party_id, %{waiting_for: ids, joined: [], tref: tref})
          end)

        {:reply, {:ok, self()}, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _object, _reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    case val do
      nil ->
        {:noreply, state}

      {:player, player_id} ->
        Logger.debug("Player #{player_id} went down, removing from queue")

        case remove_player(player_id, state) do
          :not_queued -> {:noreply, state}
          {:ok, state} -> {:noreply, state}
        end

      {:room, room_pid, player_ids} ->
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
  end

  @impl true
  def handle_info(:tick, state) do
    new_state =
      case match_members(state) do
        :no_match ->
          state

        {:match, matches} ->
          {pairings, monitors} =
            Enum.reduce(matches, {[], state.monitors}, fn teams, {ts, monitors} ->
              {:ok, pid} =
                PairingRoom.start(state.id, state.queue, teams, state.settings.pairing_timeout)

              player_ids =
                for team <- teams, member <- team, player_id <- member.player_ids do
                  player_id
                end

              monitors = MC.monitor(monitors, pid, {:room, pid, player_ids})

              {[{pid, player_ids} | ts], monitors}
            end)

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
          |> Map.replace!(:monitors, monitors)
          |> Map.update(:pairings, pairings, fn ps -> pairings ++ ps end)
      end

    {:noreply, new_state}
  end

  def handle_info({:cancel_party, party_id}, state) do
    case Map.get(state.pending_parties, party_id) do
      nil ->
        {:noreply, state}

      pending ->
        # a client failing to join should be infrequent, so log if that happens
        Logger.info(
          "Party #{party_id} failed to join, waiting for #{inspect(pending.waiting_for)}"
        )

        Enum.each(pending.joined, &Player.matchmaking_notify_cancelled(&1, :party_user_left))
        state = %{state | pending_parties: Map.delete(state.pending_parties, party_id)}
        {:noreply, state}
    end
  end

  defp remove_player(player_id, state) do
    pending_party =
      Enum.find(state.pending_parties, fn {_, x} ->
        Enum.any?(x.waiting_for, &(player_id == &1)) || Enum.any?(x.joined, &(player_id == &1))
      end)

    if pending_party == nil,
      do: remove_member(player_id, state),
      else: remove_from_pending_parties(player_id, pending_party, state)
  end

  defp remove_member(player_id, state) do
    {to_remove, new_members} =
      Enum.split_with(state.members, fn member ->
        Enum.member?(member.player_ids, player_id)
      end)

    {pairing_to_remove, other_pairings} =
      Enum.split_with(state.pairings, fn {_, members} ->
        Enum.member?(members, player_id)
      end)

    case {to_remove, pairing_to_remove} do
      {[], []} ->
        :not_queued

      {[to_remove], _} ->
        monitors = demonitor_players(to_remove.player_ids, state.monitors)

        for p_id when p_id != player_id <- to_remove.player_ids do
          Player.matchmaking_notify_cancelled(p_id, :party_user_left)
        end

        {:ok, %{state | members: new_members, monitors: monitors}}

      # there is no case with multiple member to remove since this is prevented when adding to a queue
      {_, [{room_pid, canceled_members}]} ->
        monitors = demonitor_players(canceled_members, state.monitors)
        PairingRoom.cancel(room_pid, player_id)
        {:ok, %{state | pairings: other_pairings, monitors: monitors}}
    end
  end

  defp remove_from_pending_parties(player_id, {party_id, pending_party}, state) do
    for p_id when p_id != player_id <- pending_party.waiting_for ++ pending_party.joined do
      Player.matchmaking_notify_lost(p_id, :cancel)
    end

    Party.matchmaking_notify_cancel(party_id)
    :timer.cancel(pending_party.tref)

    Map.update!(state, :pending_parties, &Map.delete(&1, party_id))
  end

  @spec member_can_join_queue?([T.userid()], state()) :: :ok | {:error, reason :: term()}
  defp member_can_join_queue?(player_ids, state) do
    member_ids =
      Enum.flat_map(state.members, fn m -> m.player_ids end)
      |> MapSet.new()

    pairing_player_ids =
      for {_, player_ids} <- state.pairings, p_id <- player_ids do
        p_id
      end
      |> MapSet.new()

    new_ids = MapSet.new(player_ids)
    is_queuing = !MapSet.disjoint?(member_ids, new_ids)
    is_pairing = !MapSet.disjoint?(pairing_player_ids, new_ids)

    cond do
      Enum.count(player_ids) > state.queue.team_size ->
        {:error, :too_many_players}

      Enum.empty?(state.queue.engines) ->
        {:error, :missing_engines}

      Enum.empty?(state.queue.games) ->
        {:error, :missing_games}

      Enum.empty?(state.queue.maps) ->
        {:error, :missing_maps}

      !is_queuing && !is_pairing ->
        :ok

      true ->
        {:error, :already_queued}
    end
  end

  defp add_member_to_queue(state, new_member) do
    monitors =
      Enum.reduce(new_member.player_ids, state.monitors, fn user_id, monitors ->
        pid = Teiserver.Player.lookup_connection(user_id)

        if pid != nil do
          MC.monitor(monitors, pid, {:player, user_id})
        else
          monitors
        end
      end)

    %{state | members: [new_member | state.members], monitors: monitors}
  end

  @doc """
  This function shouldn't be public, but it's helpful for testing to export it
  Ultimately, as the complexity grows, it could be exported to another module
  dedicated to matching players, but for now this will do

  This returns a list of potential matches.
  A match is a list of teams, a team is a list of member
  """
  @spec match_members(state()) :: :no_match | {:match, [[[Member.t()]]]}
  def match_members(state) do
    {alg_module, alg_state} = state.queue.algo
    apply(alg_module, :get_matches, [state.members, alg_state])
  end

  defp demonitor_players(player_ids, monitors) do
    Enum.reduce(player_ids, monitors, fn player_id, monitors ->
      MC.demonitor_by_val(monitors, {:player, player_id}, [:flush])
    end)
  end
end
