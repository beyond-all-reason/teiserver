defmodule Teiserver.Tachyon.LoginQueue do
  @moduledoc """
  Login queue for Tachyon connections.

  Enforces a maximum number of concurrent connected players. Autohosts bypass
  this queue entirely and are handled at the handler level.

  `attempt_login/2` returns `true` if the player is admitted immediately, or
  `false` if queued. Queued players receive `{:login_accepted, user_id}` when
  a slot opens. The queue is reactive: slots open as soon as a connected player
  disconnects or the limit is raised.
  """

  use GenServer

  alias Teiserver.Config
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Player

  require Logger

  @config_key "system.User limit"

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @doc """
  Called by a player connection process to request admission.
  Returns `true` if admitted immediately, `false` if queued.
  When queued, the caller receives `{:login_accepted, user_id}` when admitted.
  """
  @spec attempt_login(pid(), T.userid()) :: boolean()
  def attempt_login(pid, user_id) do
    GenServer.call(__MODULE__, {:attempt_login, pid, user_id})
  end

  @spec get_queue_length() :: non_neg_integer()
  def get_queue_length do
    GenServer.call(__MODULE__, :queue_size)
  catch
    :exit, {:noproc, _} -> 0
  end

  @spec set_limit(non_neg_integer()) :: :ok
  def set_limit(limit) do
    GenServer.call(__MODULE__, {:set_limit, limit})
  end

  @impl GenServer
  def init(_args) do
    Logger.metadata(actor_id: "Tachyon.LoginQueue")

    state = %{
      total_limit: Config.get_site_config_cache(@config_key),
      queue: :queue.new(),
      monitors: %{}
    }

    {:ok, state}
  end

  @impl GenServer
  def handle_call(:queue_size, _from, state) do
    {:reply, :queue.len(state.queue), state}
  end

  def handle_call({:attempt_login, pid, user_id}, _from, state) do
    Process.monitor(pid)
    capacity = available_capacity(state)

    {new_state, admitted?} =
      if capacity > 0 && :queue.is_empty(state.queue) do
        {put_in(state, [:monitors, pid], :admitted), true}
      else
        member = %{pid: pid, user_id: user_id}

        new_state =
          state
          |> Map.update!(:queue, &:queue.in(member, &1))
          |> put_in([:monitors, pid], :waiting)

        {new_state, false}
      end

    {:reply, admitted?, new_state}
  end

  def handle_call({:set_limit, limit}, _from, state) do
    new_state = %{state | total_limit: limit}
    capacity = available_capacity(new_state)
    {:reply, :ok, dequeue_members(capacity, new_state)}
  end

  @impl GenServer
  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    {kind, new_monitors} = Map.pop(state.monitors, pid, nil)
    new_state = %{state | monitors: new_monitors}

    new_state =
      case kind do
        :admitted ->
          # The Horde registry may not have removed this pid yet, so
          # available_capacity/1 might not reflect the freed slot.
          # Dequeue at least 1 regardless.
          dequeue_members(max(1, available_capacity(new_state)), new_state)

        _ ->
          new_state
      end

    {:noreply, new_state}
  end

  defp dequeue_members(n, state) when n <= 0, do: state

  defp dequeue_members(n, state) do
    case :queue.out(state.queue) do
      {:empty, _} ->
        state

      {{:value, member}, rest} ->
        new_state = Map.replace!(state, :queue, rest)

        case Map.fetch(new_state.monitors, member.pid) do
          {:ok, :waiting} ->
            # Promote to admitted — no new monitor needed, we already have one
            new_state = put_in(new_state, [:monitors, member.pid], :admitted)
            send(member.pid, {:login_accepted, member.user_id})
            dequeue_members(n - 1, new_state)

          :error ->
            # Disconnected while waiting — skip without consuming a slot
            dequeue_members(n, new_state)
        end
    end
  end

  defp available_capacity(%{total_limit: limit}) do
    limit - Player.Registry.connected_count()
  end
end
