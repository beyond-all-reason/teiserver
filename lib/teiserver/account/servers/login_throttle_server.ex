defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc """
  Implement a login queue. `attempt_login` returns true mean no need to queue.
  Otherwise it is put in a queue and will later receive a {:login_accepted, userid} message
  when it is allowed to do so
  """
  use GenServer
  require Logger
  alias Teiserver.{Account, CacheUser, Config}
  alias Teiserver.Data.Types, as: T

  @typep member :: %{pid: pid(), mon_ref: reference(), user_id: T.userid()}
  @typep state :: %{
           tick_timer_ref: :timer.tref() | nil,
           queue: :queue.queue(member()),
           monitors: MapSet.t(pid())
         }

  @default_tick_period 1_000

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  @spec init(term()) :: {:ok, state()}
  def init(_args) do
    Logger.metadata(actor_id: "LoginThrottleServer")
    {:ok, timer_ref} = :timer.send_interval(@default_tick_period, :tick)

    state = %{
      tick_timer_ref: timer_ref,
      queue: :queue.new(),
      monitors: MapSet.new()
    }

    {:ok, state}
  end

  @spec get_queue_length :: non_neg_integer()
  def get_queue_length() do
    GenServer.call(__MODULE__, :queue_size)
  end

  @doc """
  This is the function call used as part of login attempts.
  """
  @spec attempt_login(pid(), T.userid()) :: boolean()
  def attempt_login(pid, userid) do
    GenServer.call(__MODULE__, {:attempt_login, pid, userid})
  end

  @doc """
  Set to :infinity to effectively disable the queue (used for test)
  """
  @spec set_tick_period(non_neg_integer() | :infinity) :: :ok
  def set_tick_period(new_interval) do
    GenServer.cast(__MODULE__, {:set_tick_period, new_interval})
    # send_login_throttle_server({:set_tick_period, new_interval})
  end

  @doc """
  used for test, to trigger the login
  """
  def tick() do
    Process.whereis(__MODULE__) |> send(:tick)
  end

  @doc """
  Used for tests, terminate and restart the genserver
  """
  def restart() do
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, __MODULE__)
    Supervisor.restart_child(Teiserver.Supervisor, __MODULE__)
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    result = :queue.len(state.queue)
    {:reply, result, state}
  end

  def handle_call({:attempt_login, pid, userid}, _from, state) do
    category = categorise_user(userid)
    capacity = get_capacity()

    can_login? = category == :instant or (capacity > 0 && :queue.is_empty(state.queue))

    new_state =
      if can_login? do
        send(pid, {:login_accepted, userid})
        state
      else
        add_user_to_queue(state, pid, userid)
      end

    {:reply, can_login?, new_state}
  end

  @impl true
  def handle_info(:tick, state) do
    capacity = get_capacity()

    if capacity <= 0 do
      {:noreply, state}
    else
      new_state = dequeue_users(capacity, state)
      {:noreply, new_state}
    end
  end

  def handle_info({:DOWN, _, :process, pid, _reason}, state) do
    # don't traverse the queue to remove the member since it's a relatively
    # expensive operation.
    # This means the queue length doesn't reflect live clients, but it's
    # not too important in my opinion
    state = Map.update!(state, :monitors, &MapSet.delete(&1, pid))
    {:noreply, state}
  end

  @impl true
  def handle_cast({:set_tick_period, new_period}, state) do
    if state.tick_timer_ref do
      :timer.cancel(state.tick_timer_ref)
    end

    if new_period == :infinity do
      {:noreply, %{state | tick_timer_ref: nil}}
    else
      tick_timer_ref = :timer.send_interval(new_period, :tick)
      {:noreply, %{state | tick_timer_ref: tick_timer_ref}}
    end
  end

  # If a user isn't allowed to login right away they need to be queued up
  # this function takes care of all the work around that
  @spec add_user_to_queue(state(), pid(), T.userid()) :: state()
  defp add_user_to_queue(state, pid, user_id) do
    member = %{pid: pid, mon_ref: Process.monitor(pid), user_id: user_id}

    state
    |> Map.update!(:queue, &:queue.in(member, &1))
    |> Map.update!(:monitors, &MapSet.put(&1, pid))
  end

  defp dequeue_users(n, state) when n <= 0, do: state

  defp dequeue_users(n, state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        state

      {{:value, member}, rest} ->
        Process.demonitor(member.mon_ref)
        member_still_connected? = MapSet.member?(state.monitors, member.pid)

        new_state =
          state
          |> Map.update!(:monitors, &MapSet.delete(&1, member.pid))
          |> Map.replace!(:queue, rest)

        if member_still_connected? do
          send(member.pid, {:login_accepted, member.user_id})
          dequeue_users(n - 1, new_state)
        else
          dequeue_users(n, new_state)
        end
    end
  end

  # some users should be able to bypass the login queue altogether.
  # Either for operational reasons: bots like spads should never be kept out
  # or for marketing reason: vips, server operators, mods and whatnot
  # there aren't many of these users, so allowing them doesn't have a big impact
  @spec categorise_user(T.userid()) :: atom
  defp categorise_user(userid) do
    user = Account.get_user_by_id(userid)
    bypass_roles = ["Bot", "Contributor", "VIP", "BAR+"]

    cond do
      CacheUser.has_any_role?(user, bypass_roles) -> :instant
      true -> :standard
    end
  end

  defp get_capacity() do
    total_limit = Config.get_site_config_cache("system.User limit")
    count = Account.count_client()
    total_limit - count
  end
end
