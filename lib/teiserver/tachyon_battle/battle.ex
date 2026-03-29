defmodule Teiserver.TachyonBattle.Battle do
  @moduledoc false
  alias Teiserver.Autohost
  alias Teiserver.Battle
  alias Teiserver.TachyonBattle.Registry
  alias Teiserver.TachyonBattle.Types, as: T

  # For now, don't do any restart. The genserver is only used to hold some
  # transient state. Later, we can attempt to reconstruct some state after
  # a restart based on the message we get.
  use GenServer, restart: :temporary

  require Logger

  @type connection_info :: %{ips: [String.t()], port: integer()}

  @type state :: %{
          id: T.id(),
          match_id: T.match_id(),
          autohost_id: Autohost.id(),
          autohost_pid: pid(),
          autohost_timeout: timeout(),
          start_script: Autohost.start_script(),
          # initialised: the battle is waiting for players to join and start the match
          # finished: the battle is over, but there are still some player in the match,
          # maybe looking at stats or whatever
          # shutting_down: only used when the engine is terminating
          battle_state: :initialised | :in_progress | :finished | :shutting_down,

          # keep track of everyone who was ever added to the battle. This is useful to limit the
          # number of players allowed, and may also be used later to limit
          # or do some actions.
          # This is not limited only to players *currently* in the battle
          participants: %{
            Teiserver.Data.Types.userid() => %{
              name: String.t(),
              password: String.t()
            }
          },

          # store the connection info for the actual battle so that player can
          # join/rejoin
          ips: [String.t()],
          port: integer()
        }

  def start(%{battle_id: battle_id} = arg) do
    GenServer.start(__MODULE__, arg, name: via_tuple(battle_id))
  end

  def start_link(%{battle_id: battle_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(battle_id))
  end

  # TODO! handle the case where the battle isn't there somehow. This
  # will become important when we start tracking event history for autohosts
  # and doing state recovery
  @spec send_update_event(Autohost.update_event()) :: :ok
  def send_update_event(event) do
    event.battle_id |> via_tuple() |> GenServer.cast({:update_event, event})
  end

  @spec send_message(T.id(), String.t()) :: :ok | {:error, reason :: term()}
  def send_message(battle_id, message) do
    battle_id |> via_tuple() |> GenServer.call({:send_message, message})
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_battle}
  end

  @spec kill(T.id()) :: :ok | {:error, reason :: term()}
  def kill(battle_id) do
    battle_id |> via_tuple() |> GenServer.call(:kill)
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_battle}
  end

  @spec add_player(
          T.id(),
          Teiserver.Data.Types.userid(),
          name :: String.t(),
          password :: String.t()
        ) :: {:ok, connection_info()} | {:error, term()}
  def add_player(battle_id, user_id, name, password) do
    via_tuple(battle_id) |> GenServer.call({:add_player, user_id, name, password})
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_battle}
  end

  @doc """
  the bits required for a client to connect to an ongoing battle
  """
  @spec get_connection_info(T.id()) :: {:ok, connection_info()} | {:error, :invalid_battle}
  def get_connection_info(battle_id) do
    via_tuple(battle_id) |> GenServer.call(:get_connection_info)
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_battle}
  end

  @doc """
  This should only be used for test purpose (for now). If required outside of
  test, consider if a battle should indeed expose (db) match details
  """
  def get_match_id(battle_id) do
    via_tuple(battle_id) |> GenServer.call(:get_match_id)
  end

  @impl GenServer
  def init(
        %{
          battle_id: battle_id,
          match_id: match_id,
          autohost_id: autohost_id,
          start_script: start_script
        } = args
      ) do
    Logger.metadata(actor_type: :battle, actor_id: battle_id)

    Logger.info(
      "Starting battle with id #{battle_id} and match id #{match_id} on autohost #{autohost_id}"
    )

    players =
      for at <- start_script.ally_teams, team <- at.teams, p <- team.players, into: %{} do
        {p.user_id, %{name: p.name, password: p.password}}
      end

    # currently, the lobby will automatically add specs to the game at start.
    # if this changes, we should also update this bit
    specs =
      for spec <- Map.get(start_script, :spectators, []), into: %{} do
        {spec.user_id, %{name: spec.name, password: spec.password}}
      end

    state = %{
      id: battle_id,
      match_id: match_id,
      autohost_id: autohost_id,
      autohost_pid: nil,
      start_script: start_script,
      # the timeout is absurdly short because there is no real recovery if the
      # autohost goes away. When we implement state recovery this timeout
      # should be increased to a more reasonable value (1 min?)
      # Need to also fix the autohost_pid when it comes back
      autohost_timeout: Map.get(args, :autohost_timeout, 100),
      battle_state: :initialised,
      participants: Map.merge(players, specs)
    }

    # we need an overall timeout to avoid any potential zombie process
    # 8h is more than enough time for any online game
    :timer.send_after(8 * 60 * 60_000, :battle_timeout)

    case Autohost.start_battle(autohost_id, battle_id, self(), start_script) do
      {:ok, autohost_pid, data} ->
        Logger.info("battle initialised with autohost #{autohost_id}")
        Process.monitor(autohost_pid)

        new_state =
          state
          |> Map.put(:autohost_pid, autohost_pid)
          |> Map.put(:ips, data.ips)
          |> Map.put(:port, data.port)

        {:ok, new_state}

      {:error, err} ->
        Logger.error("Cannot start battle with autohost #{autohost_id}")
        {:stop, err}
    end
  end

  @impl GenServer
  def handle_call(:get_connection_info, _from, state) do
    {:reply, {:ok, Map.take(state, [:ips, :port])}, state}
  end

  def handle_call({:send_message, msg}, _from, state) do
    case state.autohost_id do
      nil ->
        {:reply, {:error, :no_autohost}, state}

      id ->
        payload = %{battle_id: state.id, message: msg}
        resp = Autohost.send_message(id, payload)
        {:reply, resp, state}
    end
  end

  def handle_call(:kill, _from, state) do
    case state.autohost_pid do
      nil ->
        {:reply, {:error, :no_autohost}, state}

      pid ->
        resp = Autohost.kill_battle(pid, state.id)
        {:reply, resp, state}
    end

    # Note that we don't terminate the battle process here.
    # I believe it should happen when, after closing the engine, autohost
    # should send :engine_quit message (or something similar)
    # if that's not the case, we should terminate here
  end

  def handle_call({:add_player, user_id, name, password}, _from, state) do
    case {state.autohost_pid, Map.get(state.participants, user_id)} do
      {nil, _participant} ->
        {:reply, {:error, :no_autohost}, state}

      {_pid, participant} when not is_nil(participant) ->
        {:reply, {:ok, Map.take(state, [:ips, :port])}, state}

      # The engine cannot deal with a total of more than 254 players
      # https://github.com/beyond-all-reason/RecoilEngine/issues/2850
      _irrelevant when map_size(state.participants) >= 254 ->
        {:reply, {:error, :capacity_reached}, state}

      {pid, nil} ->
        data = %{battle_id: state.id, user_id: user_id, name: name, password: password}

        case Autohost.add_player(pid, data) do
          :ok ->
            resp = {:ok, Map.take(state, [:ips, :port])}
            state = put_in(state, [:participants, user_id], %{name: name, password: password})
            {:reply, resp, state}

          {:error, err} ->
            {:reply, {:error, err}, state}
        end
    end
  end

  def handle_call(:get_match_id, _from, state) do
    {:reply, state.match_id, state}
  end

  @impl GenServer
  def handle_cast({:update_event, ev}, state) do
    if state.autohost_pid != nil,
      do: Autohost.ack_update_event(state.autohost_pid, state.id, ev.time)

    case ev.update do
      :start ->
        Battle.start_tachyon_match(state.match_id, ev.time)
        {:noreply, %{state | battle_state: :in_progress}}

      {:finished, %{user_id: user_id, winning_ally_teams: winning_ally_teams}} ->
        Battle.end_tachyon_match(state.match_id, ev.time, user_id, winning_ally_teams)
        {:noreply, %{state | battle_state: :finished}}

      {:engine_crash, _details} ->
        Battle.end_tachyon_match(state.match_id, ev.time)
        {:stop, :shutdown, %{state | battle_state: :shutting_down}}

      :engine_quit ->
        Battle.end_tachyon_match(state.match_id, ev.time)
        Battle.rate_tachyon_match(state.match_id)
        {:stop, :shutdown, %{state | battle_state: :shutting_down}}

      {:player_chat_broadcast, %{destination: :all, message: "!stop"}} ->
        if state.autohost_pid != nil do
          Autohost.kill_battle(state.autohost_pid, state.id)
          {:noreply, state}
        else
          {:noreply, state}
        end

      _other ->
        {:noreply, state}
    end
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    timeout = state.autohost_timeout
    if timeout != :infinity, do: :timer.send_after(timeout, :autohost_timeout)
    {:noreply, %{state | autohost_pid: nil}}
  end

  def handle_info(:autohost_timeout, state) do
    Logger.info("Autohost #{state.autohost_id} disconnected for too long, shutting down battle")
    {:stop, :normal, state}
  end

  def handle_info(:battle_timeout, state) do
    Logger.info("Battle shutting down to save resources")
    {:stop, :normal, state}
  end

  defp via_tuple(battle_id) do
    Registry.via_tuple(battle_id)
  end
end
