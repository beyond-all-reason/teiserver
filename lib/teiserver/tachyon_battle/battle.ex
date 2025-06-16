defmodule Teiserver.TachyonBattle.Battle do
  require Logger

  alias Teiserver.TachyonBattle.Types, as: T
  alias Teiserver.TachyonBattle.Registry

  # For now, don't do any restart. The genserver is only used to hold some
  # transient state. Later, we can attempt to reconstruct some state after
  # a restart based on the message we get.
  use GenServer, restart: :temporary

  @type state :: %{
          id: T.id(),
          autohost_id: Teiserver.Autohost.id(),
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
    GenServer.call(via_tuple(event.battle_id), {:update_event, event})
  end

  @impl true
  def init(%{battle_id: battle_id, autohost_id: autohost_id} = args) do
    Logger.metadata(actor_type: :battle, actor_id: battle_id)

    state = %{
      id: battle_id,
      autohost_id: autohost_id,
      # the timeout is absurdly short because there is no real recovery if the
      # autohost goes away. When we implement state recovery this timeout
      # should be increased to a more reasonable value (1 min?)
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
        {:ok, state}

      nil ->
        {:stop, :no_autohost}
    end
  end

  @impl true
  def handle_call({:update_event, ev}, _from, state) do
    case ev.update do
      :start -> {:reply, :ok, %{state | battle_state: :in_progress}}
      {:finished, _} -> {:reply, :ok, %{state | battle_state: :finished}}
      {:engine_crash, _} -> {:stop, :shutdown, :ok, %{state | battle_state: :shutting_down}}
      :engine_quit -> {:stop, :shutdown, :ok, %{state | battle_state: :shutting_down}}
      _ -> {:reply, :ok, state}
    end
  end

  @impl true
  def handle_info({:DOWN, _ref, :process, _pid, _reason}, state) do
    timeout = state.autohost_timeout
    if timeout != :infinity, do: :timer.send_after(timeout, :autohost_timeout)
    {:noreply, state}
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
