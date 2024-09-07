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

  @type matchmaking_state ::
          :no_matchmaking
          | {:searching,
             %{
               joined_queues: nonempty_list(Matchmaking.queue_id())
             }}
          | {:pairing,
             %{
               pairing_state: :notified,
               paired_queue: Matchmaking.queue_id(),
               # a list of the other queues to rejoin in case the pairing fails
               frozen_queues: [Matchmaking.queue_id()]
             }}

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

  @doc """
  Cleanly disconnect the user, clearing any state
  """
  @spec disconnect(T.userid()) :: :ok
  def disconnect(user_id) do
    # the registry will automatically unregister when the process terminates
    # but that can lead to race conditions when a player disconnect and
    # reconnect immediately
    Player.SessionRegistry.unregister(user_id)
    GenServer.call(via_tuple(user_id), :disconnect)
  end

  @spec join_queues(T.userid(), [Matchmaking.queue_id()]) :: Matchmaking.join_result()
  def join_queues(user_id, queue_ids) do
    GenServer.call(via_tuple(user_id), {:join_queues, queue_ids})
  end

  @doc """
  Leave all the queues, and effectively removes the player from any matchmaking
  """
  @spec leave_queues(T.userid()) :: Matchmaking.leave_result()
  def leave_queues(user_id) do
    GenServer.call(via_tuple(user_id), :leave_queues)
  end

  @spec notify_found(T.userid(), Matchmaking.queue_id(), timeout()) :: :ok
  def notify_found(user_id, queue_id, timeout_ms) do
    GenServer.cast(via_tuple(user_id), {:notify_found, queue_id, timeout_ms})
  end

  def start_link({_conn_pid, user_id} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(user_id))
  end

  @doc """
  To forcefully disconnect a connected player and replace this connection
  with another one. This is to avoid having the same player with several
  connections.
  """
  @spec replace_connection(pid(), pid()) :: :ok | :died
  def replace_connection(sess_pid, new_conn_pid) do
    GenServer.call(sess_pid, {:replace, new_conn_pid})
  catch
    :exit, _ ->
      :died
  end

  @impl true
  def init({conn_pid, user_id}) do
    ref = Process.monitor(conn_pid)

    state = %{
      user_id: user_id,
      mon_ref: ref,
      conn_pid: conn_pid,
      matchmaking: initial_matchmaking_state()
    }

    {:ok, state}
  end

  defp initial_matchmaking_state() do
    :no_matchmaking
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

  def handle_call(:disconnect, _from, state) do
    user_id = state.user_id

    case state.matchmaking do
      {:searching, %{joined_queues: joined_queues}} ->
        Enum.each(joined_queues, fn queue_id ->
          Matchmaking.QueueServer.leave_queue(queue_id, user_id)
        end)

      _ ->
        nil
    end

    {:stop, :normal, :ok, %{state | matchmaking: initial_matchmaking_state()}}
  end

  # this should never happen because the json schema already checks for minimum length
  def handle_call({:join_queues, []}, _from, state),
    do: {:reply, {:error, :invalid_request}, state}

  def handle_call({:join_queues, queue_ids}, _from, state) do
    case state.matchmaking do
      :no_matchmaking ->
        case join_all_queues(state.user_id, queue_ids, []) do
          :ok ->
            new_mm_state = {:searching, %{joined_queues: queue_ids}}
            {:reply, :ok, put_in(state.matchmaking, new_mm_state)}

          {:error, err} ->
            {:reply, {:error, err}, state}
        end

      {:searching, _} ->
        {:reply, {:error, :already_queued}, state}
    end
  end

  def handle_call(:leave_queues, _from, state) do
    case state.matchmaking do
      :no_matchmaking ->
        {:reply, {:error, :not_queued}, state}

      {:searching, %{joined_queues: joined_queues}} ->
        # TODO tachyon_mvp: leaving queue ignore failure there.
        # It is a bit unclear what kind of failure can happen, and also
        # what should be done in that case
        Enum.each(joined_queues, fn qid ->
          Matchmaking.leave_queue(qid, state.user_id)
        end)

        {:reply, :ok, Map.put(state, :matchmaking, initial_matchmaking_state())}
        # TODO add the logic to leave the pairing room as well when leaving queues
    end
  end

  @impl true
  def handle_cast(
        {:notify_found, queue_id, timeout_ms},
        %{matchmaking: {:searching, %{joined_queues: queue_ids}}} = state
      ) do
    if not Enum.member?(queue_ids, queue_id) do
      {:noreply, state}
    else
      # TODO tachyon_mvp: what should server do if the connection is down at that time?
      # The best is likely to store it and send the notification upon reconnection
      if state.conn_pid != nil do
        send(state.conn_pid, {:notify_found, queue_id, timeout_ms})
      end

      other_queues =
        for qid <- queue_ids, qid != queue_id do
          Matchmaking.leave_queue(qid, state.user_id)
          qid
        end

      new_mm_state =
        {:pairing,
         %{pairing_state: :notified, paired_queue: queue_id, frozen_queues: other_queues}}

      new_state = Map.put(state, :matchmaking, new_mm_state)
      {:noreply, new_state}
    end
  end

  def handle_cast({:notify_found, _queue_id, _}, state) do
    # we're not searching anything. This can happen as a race when two queues
    # match the same player at the same time.
    # TODO tachyon_mvp: need to decline the pairing here
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _reason}, state) when ref == state.mon_ref do
    # we don't care about cancelling the timer if the player reconnects since reconnection
    # should be fairly low (and rate limited) so too many messages isn't an issue
    {:ok, _} = :timer.send_after(30_000, :player_timeout)
    {:noreply, %{state | conn_pid: nil}}
  end

  def handle_info(:player_timeout, state) do
    if is_nil(state.conn_pid) do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  defp via_tuple(user_id) do
    Player.SessionRegistry.via_tuple(user_id)
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
end
