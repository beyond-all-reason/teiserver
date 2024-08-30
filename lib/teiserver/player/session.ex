defmodule Teiserver.Player.Session do
  @moduledoc """
  A session has a link to a player connection, but can outlive it.
  This is a separate process that should be used to check whether a player
  is online.

  It holds very minimal state regarding the connection.
  """

  use GenServer
  require Logger

  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Player, Matchmaking}

  @type conn_state :: :connected | :reconnecting | :disconnected

  @type matchmaking_state :: %{
          joined_queues: [Matchmaking.queue_id()]
        }

  @type state :: %{
          user_id: T.userid(),
          mon_ref: reference(),
          conn_pid: pid() | nil,
          matchmaking: matchmaking_state()
        }

  @spec conn_state(T.userid()) :: conn_state()
  def conn_state(user_id) do
    GenServer.call(via_tuple(user_id), :conn_state)
  catch
    :exit, {:noproc, _} ->
      :disconnected
  end

  @spec join_queues(T.userid(), [Matchmaking.queue_id()]) :: Matchmaking.join_result()
  def join_queues(user_id, queue_ids) do
    GenServer.call(via_tuple(user_id), {:join_queues, queue_ids})
  end

  def start_link({_conn_pid, user_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(user_id))
  end

  @doc """
  To forcefully disconnect a connected player and replace this connection
  with another one. This is to avoid having the same player with several
  connections.
  """
  @spec replace_connection(pid(), pid()) :: :ok
  def replace_connection(sess_pid, new_conn_pid) do
    GenServer.call(sess_pid, {:replace, new_conn_pid})
  end

  @impl true
  def init({conn_pid, user_id}) do
    ref = Process.monitor(conn_pid)

    state = %{
      user_id: user_id,
      mon_ref: ref,
      conn_pid: conn_pid,
      matchmaking_state: %{
        joined_queues: []
      }
    }

    {:ok, state}
  end

  @impl true
  def handle_call({:replace, _}, _from, state) when is_nil(state.conn_pid),
    do: {:reply, :ok, state}

  def handle_call({:replace, new_conn_pid}, _from, state) do
    Process.demonitor(state.mon_ref, [:flush])

    mon_ref = Process.monitor(new_conn_pid)

    {:reply, :ok, %{state | conn_pid: new_conn_pid, mon_ref: mon_ref}}
  end

  def handle_call(:conn_state, _from, state) do
    result = if is_nil(state.conn_pid), do: :reconnecting, else: :connected
    {:reply, result, state}
  end

  def handle_call({:join_queues, queue_ids}, _from, state) do
    if not Enum.empty?(state.matchmaking_state.joined_queues) do
      {:reply, {:error, :already_queued}, state}
    else
      case join_all_queues(state.user_id, queue_ids, []) do
        :ok ->
          {:reply, :ok, put_in(state.matchmaking_state.joined_queues, queue_ids)}

        {:error, err} ->
          {:reply, {:error, err}, state}
      end
    end
  end

  @spec join_all_queues(T.userid(), [Matchmaking.queue_id()], [Matchmaking.queue_id()]) ::
          Matchmaking.join_result()
  defp join_all_queues(_user_id, [], _joined), do: :ok

  defp join_all_queues(user_id, [to_join | rest], joined) do
    case Matchmaking.join_queue(to_join, user_id) do
      :ok ->
        join_all_queues(user_id, rest, [to_join | joined])

      # the `queue` message is all or nothing, so if joining a later queue need
      # to leave the queues already joined
      {:error, reason} ->
        Enum.each(joined, fn qid -> Matchmaking.leave_queue(qid, user_id) end)

        {:error, reason}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _reason}, state) when ref == state.mon_ref do
    {:noreply, %{state | conn_pid: nil}}
  end

  defp via_tuple(user_id) do
    Player.SessionRegistry.via_tuple(user_id)
  end
end
