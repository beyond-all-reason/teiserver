defmodule Teiserver.TachyonBattle.Battle do
  require Logger

  alias Teiserver.Autohost
  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.TachyonBattle.Registry

  # For now, don't do any restart. The genserver is only used to hold some
  # transient state. Later, we can attempt to reconstruct some state after
  # a restart based on the message we get.
  use GenServer, restart: :temporary

  @type state :: %{
          id: T.id(),
          autohost_id: Teiserver.Autohost.id(),
          autohost_pid: pid(),
          autohost_timeout: timeout(),
          # initialised: the battle is waiting for players to join and start the match
          # finished: the battle is over, but there are still some player in the match,
          # maybe looking at stats or whatever
          # shutting_down: only used when the engine is terminating
          battle_state: :initialised | :in_progress | :finished | :shutting_down
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
  @spec send_update_event(Teiserver.Autohost.update_event()) :: :ok
  def send_update_event(event) do
    GenServer.cast(via_tuple(event.battle_id), {:update_event, event})
  end

  @spec send_message(T.id(), String.t()) :: :ok | {:error, reason :: term()}
  def send_message(battle_id, message) do
    GenServer.call(via_tuple(battle_id), {:send_message, message})
  catch
    :exit, {:noproc, _} -> {:error, :invalid_battle}
  end

  @spec kill(T.id()) :: :ok | {:error, reason :: term()}
  def kill(battle_id) do
    GenServer.call(via_tuple(battle_id), :kill)
  catch
    :exit, {:noproc, _} -> {:error, :invalid_battle}
  end

  @impl true
  def init(%{battle_id: battle_id, autohost_id: autohost_id} = args) do
    Logger.metadata(actor_type: :battle, actor_id: battle_id)

    state = %{
      id: battle_id,
      autohost_id: autohost_id,
      autohost_pid: nil,
      # the timeout is absurdly short because there is no real recovery if the
      # autohost goes away. When we implement state recovery this timeout
      # should be increased to a more reasonable value (1 min?)
      # Need to also fix the autohost_pid when it comes back
      autohost_timeout: Map.get(args, :autohost_timeout, 100),
      battle_state: :initialised
    }

    # we need an overall timeout to avoid any potential zombie process
    # 8h is more than enough time for any online game
    :timer.send_after(8 * 60 * 60_000, :battle_timeout)

    case Teiserver.Autohost.lookup_autohost(autohost_id) do
      {pid, _} ->
        Logger.info("init battle for autohost #{autohost_id}")
        Process.monitor(pid)
        {:ok, %{state | autohost_pid: pid}}

      nil ->
        {:stop, :no_autohost}
    end
  end

  @impl true
  def handle_call({:send_message, msg}, _from, state) do
    case state.autohost_pid do
      nil ->
        {:reply, {:error, :no_autohost}, state}

      pid ->
        payload = %{battle_id: state.id, message: msg}
        resp = Autohost.send_message(pid, payload)
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

  @impl true
  def handle_cast({:update_event, ev}, state) do
    case ev.update do
      :start ->
        {:noreply, %{state | battle_state: :in_progress}}

      {:finished, _} ->
        {:noreply, %{state | battle_state: :finished}}

      {:engine_crash, _} ->
        {:stop, :shutdown, %{state | battle_state: :shutting_down}}

      :engine_quit ->
        {:stop, :shutdown, %{state | battle_state: :shutting_down}}

      {:player_chat_broadcast, %{destination: :all, message: "!stop"}} ->
        if state.autohost_pid != nil do
          Autohost.kill_battle(state.autohost_pid, state.id)
          {:noreply, state}
        else
          {:noreply, state}
        end

      _ ->
        {:noreply, state}
    end
  end

  @impl true
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
