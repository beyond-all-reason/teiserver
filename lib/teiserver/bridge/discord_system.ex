defmodule Teiserver.Bridge.DiscordSystem do
  @moduledoc """
  Manages the Discord bridge lifecycle with crash isolation and automatic restart.

  When the Discord bridge crashes, this process catches the exit (via trap_exit),
  logs it, and schedules a restart with exponential backoff. This ensures Nostrum
  failures never propagate to the rest of the application.

  Backoff starts at 1 second and doubles on each consecutive failure, capping at
  5 minutes. After 5 minutes of stable operation the backoff resets to 1 second.
  """

  alias Teiserver.Bridge.DiscordSupervisor
  alias Teiserver.Communication

  use GenServer

  require Logger

  @initial_backoff_ms :timer.seconds(1)
  @max_backoff_ms :timer.minutes(5)
  @backoff_reset_after_ms :timer.minutes(5)

  @spec start_link(args :: any()) :: {:ok, pid()} | {:error, term()}
  def start_link(_init_arg) do
    GenServer.start_link(__MODULE__, [], name: __MODULE__)
  end

  @doc """
  Manually restart the Discord bridge, resetting the backoff timer.
  Returns `{:ok, pid}` on success or `{:error, reason}` on failure.
  """
  @spec restart() :: {:ok, pid()} | {:error, term()}
  def restart do
    GenServer.call(__MODULE__, :restart, 15_000)
  end

  @impl GenServer
  def init(_init_arg) do
    Process.flag(:trap_exit, true)

    state = %{
      pid: nil,
      backoff_ms: @initial_backoff_ms,
      restart_timer: nil,
      reset_timer: nil
    }

    if Communication.use_discord?() do
      send(self(), :start_discord)
    end

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:restart, _from, state) do
    state = stop_discord(state)

    case start_discord() do
      {:ok, pid} ->
        state = %{state | pid: pid, backoff_ms: @initial_backoff_ms}
        state = schedule_backoff_reset(state)
        {:reply, {:ok, pid}, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  @impl GenServer
  def handle_info(:start_discord, state) do
    case start_discord() do
      {:ok, pid} ->
        Logger.info("Discord bridge started successfully")
        state = %{state | pid: pid}
        state = schedule_backoff_reset(state)
        {:noreply, state}

      {:error, reason} ->
        Logger.warning(
          "Failed to start Discord bridge: #{inspect(reason)}, retrying in #{state.backoff_ms}ms"
        )

        state = schedule_restart(state)
        {:noreply, state}
    end
  end

  def handle_info({:EXIT, pid, :shutdown}, %{pid: pid} = state) do
    # Clean shutdown, don't auto-restart (e.g. manual stop or app shutdown)
    state = cancel_reset_timer(state)
    {:noreply, %{state | pid: nil}}
  end

  def handle_info({:EXIT, pid, reason}, %{pid: pid} = state) do
    state = cancel_reset_timer(state)

    Logger.warning(
      "Discord bridge crashed (#{inspect(reason)}), restarting in #{state.backoff_ms}ms"
    )

    state = %{state | pid: nil}
    state = schedule_restart(state)
    {:noreply, state}
  end

  def handle_info({:EXIT, _pid, _reason}, state) do
    # Exit from some other linked process, ignore
    {:noreply, state}
  end

  def handle_info(:reset_backoff, state) do
    Logger.info("Discord bridge stable, resetting backoff")
    {:noreply, %{state | backoff_ms: @initial_backoff_ms, reset_timer: nil}}
  end

  @impl GenServer
  def terminate(_reason, state) do
    stop_discord(state)
    :ok
  end

  defp start_discord do
    case DiscordSupervisor.start_link([]) do
      {:ok, pid} -> {:ok, pid}
      {:error, {:already_started, pid}} -> {:ok, pid}
      {:error, reason} -> {:error, reason}
    end
  end

  defp stop_discord(%{pid: nil} = state) do
    state
    |> cancel_restart_timer()
    |> cancel_reset_timer()
  end

  defp stop_discord(%{pid: pid} = state) do
    state =
      state
      |> cancel_restart_timer()
      |> cancel_reset_timer()

    if Process.alive?(pid) do
      Process.exit(pid, :shutdown)

      receive do
        {:EXIT, ^pid, _reason} -> :ok
      after
        5_000 -> :ok
      end
    end

    %{state | pid: nil}
  end

  defp schedule_restart(state) do
    state = cancel_restart_timer(state)
    timer = Process.send_after(self(), :start_discord, state.backoff_ms)
    next_backoff = min(state.backoff_ms * 2, @max_backoff_ms)
    %{state | restart_timer: timer, backoff_ms: next_backoff}
  end

  defp schedule_backoff_reset(state) do
    state = cancel_reset_timer(state)
    timer = Process.send_after(self(), :reset_backoff, @backoff_reset_after_ms)
    %{state | reset_timer: timer}
  end

  defp cancel_restart_timer(%{restart_timer: nil} = state), do: state

  defp cancel_restart_timer(%{restart_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | restart_timer: nil}
  end

  defp cancel_reset_timer(%{reset_timer: nil} = state), do: state

  defp cancel_reset_timer(%{reset_timer: timer} = state) do
    Process.cancel_timer(timer)
    %{state | reset_timer: nil}
  end
end
