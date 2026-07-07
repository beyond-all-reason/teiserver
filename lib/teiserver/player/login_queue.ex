defmodule Teiserver.Player.LoginQueue do
  @moduledoc """
  Login queue for Tachyon connections.

  Enforces a maximum number of concurrent connected players. Autohosts bypass
  this queue entirely and are handled at the handler level.

  `attempt_login/1` returns `true` if the player is admitted immediately, or
  `false` if queued. On each tick, available capacity is checked and queued
  players are admitted in FIFO order. Disconnected waiting players are skipped.
  """

  alias Teiserver.Account.User
  alias Teiserver.Config
  alias Teiserver.Helpers.BurstyRateLimiter
  alias Teiserver.Player.SessionRegistry
  alias Teiserver.Player.TachyonHandler

  use GenServer

  @limit_config_key "tachyon.Login queue limit"
  @default_tick_period 1_000
  @rate_config_key "tachyon.Login rate"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Called by a player connection process to request admission.
  Returns `true` if admitted immediately, `false` if queued.

  When queued, the caller will be notified via `TachyonHandler.notify_login_accepted/1`
  once a slot opens up.
  """
  @spec attempt_login(User.id(), pid()) :: boolean()
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
  Set the login rate (users per minute).
  If `should_fill?` is true, the new rate limiter starts with full permits and
  admits users immediately up to the burst capacity.
  """
  @spec set_rate(BurstyRateLimiter.t()) :: :ok
  def set_rate(%BurstyRateLimiter{} = rl) do
    GenServer.call(__MODULE__, {:set_rate, rl})
  end

  @spec set_rate(non_neg_integer(), boolean()) :: :ok
  def set_rate(rate, should_fill? \\ false)

  def set_rate(rate, true),
    do: rate |> BurstyRateLimiter.per_minute() |> BurstyRateLimiter.set_full() |> set_rate()

  def set_rate(rate, false),
    do: rate |> BurstyRateLimiter.per_minute() |> BurstyRateLimiter.set_empty() |> set_rate()

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

    default_rate = Config.get_site_config_cache(@rate_config_key)
    rate_limiter = BurstyRateLimiter.per_minute(default_rate) |> BurstyRateLimiter.set_empty()

    state = %{
      tick_timer_ref: timer_ref,
      total_limit: Config.get_site_config_cache(@limit_config_key),
      queue: :queue.new(),
      monitors: MapSet.new(),
      rate_limiter: rate_limiter
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
      case BurstyRateLimiter.try_acquire(state.rate_limiter) do
        {:ok, updated_rl} ->
          {:reply, true, %{state | rate_limiter: updated_rl}}

        _error ->
          {:reply, false, enqueue_member(state, pid, user_id)}
      end
    else
      {:reply, false, enqueue_member(state, pid, user_id)}
    end
  end

  def handle_call({:set_limit, limit}, _from, state) do
    {:reply, :ok, %{state | total_limit: limit}}
  end

  def handle_call({:set_rate, %BurstyRateLimiter{} = rl}, _from, state) do
    {:reply, :ok, %{state | rate_limiter: rl}}
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

  defp enqueue_member(state, pid, user_id) do
    mon_ref = Process.monitor(pid)
    member = %{pid: pid, mon_ref: mon_ref, user_id: user_id}

    state
    |> Map.update!(:queue, &:queue.in(member, &1))
    |> Map.update!(:monitors, &MapSet.put(&1, pid))
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
          case BurstyRateLimiter.try_acquire(new_state.rate_limiter) do
            {:ok, rl} ->
              TachyonHandler.notify_login_accepted(member.pid)
              dequeue_members(n - 1, %{new_state | rate_limiter: rl})

            _error ->
              state
          end
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
      default: 1_000_000,
      update_callback: &__MODULE__.set_limit/1
    })

    Config.add_site_config_type(%{
      key: @rate_config_key,
      section: "Tachyon",
      type: "integer",
      permissions: ["Admin"],
      description: "How many users per minute can log in via Tachyon",
      default: 100_000,
      update_callback: &__MODULE__.set_rate/1
    })
  end
end
