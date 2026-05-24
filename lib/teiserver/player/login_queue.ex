defmodule Teiserver.Player.LoginQueue do
  @moduledoc """
  Login queue for Tachyon connections.

  Enforces a maximum number of concurrent connected players. Autohosts bypass
  this queue entirely and are handled at the handler level.

  `attempt_login/1` returns `true` if the player is admitted immediately, or
  `false` if queued. On each tick, available capacity is checked and queued
  players are admitted in FIFO order. Disconnected waiting players are skipped.
  """

  alias Teiserver.Config
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Player.SessionRegistry
  alias Teiserver.Player.TachyonHandler

  use GenServer

  require Logger

  @limit_config_key "tachyon.Login queue limit"
  @default_tick_period 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Called by a player connection process to request admission.
  Returns `true` if admitted immediately, `false` if queued.

  When queued, the caller will be notified via `TachyonHandler.notify_login_accepted/1`
  once a slot opens up.
  """
  @spec attempt_login(T.userid(), pid()) :: boolean()
  def attempt_login(user_id, pid \\ self()) do
    GenServer.call(__MODULE__, {:attempt_login, pid, user_id})
  end

  @spec get_queue_length() :: non_neg_integer()
  def get_queue_length do
    GenServer.call(__MODULE__, :queue_size)
  catch
    :exit, {:noproc, _reason} -> 0
  end

  @spec set_limit(non_neg_integer()) :: :ok
  def set_limit(limit) do
    GenServer.call(__MODULE__, {:set_limit, limit})
  end

  @spec set_tick_period(non_neg_integer() | :infinity) :: :ok
  def set_tick_period(new_period) do
    GenServer.cast(__MODULE__, {:set_tick_period, new_period})
  end

  @doc """
  Manually trigger a tick. Used in tests to control timing deterministically.
  """
  def tick do
    send(__MODULE__, :tick)
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(actor_id: :login_queue)
    {:ok, timer_ref} = :timer.send_interval(@default_tick_period, :tick)

    state = %{
      tick_timer_ref: timer_ref,
      total_limit: Config.get_site_config_cache(@limit_config_key),
      queue: :queue.new(),
      monitors: MapSet.new()
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:queue_size, _from, state) do
    {:reply, :queue.len(state.queue), state}
  end

  def handle_call({:attempt_login, pid, user_id}, _from, state) do
    capacity = available_capacity(state)

    if capacity > 0 && :queue.is_empty(state.queue) do
      {:reply, true, state}
    else
      mon_ref = Process.monitor(pid)
      member = %{pid: pid, mon_ref: mon_ref, user_id: user_id}

      new_state =
        state
        |> Map.update!(:queue, &:queue.in(member, &1))
        |> Map.update!(:monitors, &MapSet.put(&1, pid))

      {:reply, false, new_state}
    end
  end

  def handle_call({:set_limit, limit}, _from, state) do
    {:reply, :ok, %{state | total_limit: limit}}
  end

  @impl GenServer
  def handle_cast({:set_tick_period, new_period}, state) do
    if state.tick_timer_ref do
      :timer.cancel(state.tick_timer_ref)
    end

    if new_period == :infinity do
      {:noreply, %{state | tick_timer_ref: nil}}
    else
      {:ok, timer_ref} = :timer.send_interval(new_period, :tick)
      {:noreply, %{state | tick_timer_ref: timer_ref}}
    end
  end

  @impl GenServer
  def handle_info(:tick, state) do
    capacity = available_capacity(state)

    if capacity <= 0 do
      {:noreply, state}
    else
      {:noreply, dequeue_members(capacity, state)}
    end
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {:noreply, Map.update!(state, :monitors, &MapSet.delete(&1, pid))}
  end

  defp dequeue_members(n, state) when n <= 0, do: state

  defp dequeue_members(n, state) do
    case :queue.out(state.queue) do
      {:empty, _queue} ->
        state

      {{:value, member}, rest} ->
        Process.demonitor(member.mon_ref, [:flush])
        still_connected? = MapSet.member?(state.monitors, member.pid)

        new_state =
          state
          |> Map.update!(:monitors, &MapSet.delete(&1, member.pid))
          |> Map.replace!(:queue, rest)

        if still_connected? do
          TachyonHandler.notify_login_accepted(member.pid)
          dequeue_members(n - 1, new_state)
        else
          dequeue_members(n, new_state)
        end
    end
  end

  defp available_capacity(%{total_limit: limit}) do
    limit - SessionRegistry.count()
  end

  def setup_site_configs do
    Config.add_site_config_type(%{
      key: @limit_config_key,
      section: "Tachyon",
      type: "integer",
      permissions: ["Admin"],
      description: "Maximum number of concurrent Tachyon player sessions",
      default: 1000
    })
  end
end
