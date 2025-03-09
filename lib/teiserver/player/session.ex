defmodule Teiserver.Player.Session do
  @moduledoc """
  A session has a link to a player connection, but can outlive it.
  This is a separate process that should be used to check whether a player
  is online.

  It holds very minimal state regarding the connection.
  """

  # For now, never restart a session. Until some form of state persistence is
  # implemented it's better to just remove the process completely than
  # restarting with an invalid state
  use GenServer, restart: :temporary
  require Logger

  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Player, Matchmaking, Messaging}
  alias Teiserver.Helpers.BoundedQueue, as: BQ

  @type conn_state :: :connected | :reconnecting | :disconnected

  @type matchmaking_state ::
          :no_matchmaking
          | {:searching,
             %{
               joined_queues: nonempty_list(Matchmaking.queue_id())
             }}
          | {:pairing,
             %{
               paired_queue: Matchmaking.queue_id(),
               room: {pid(), reference()},
               # a list of the other queues to rejoin in case the pairing fails
               frozen_queues: [Matchmaking.queue_id()],
               readied: boolean(),
               battle_password: String.t()
             }}

  @type messaging_state :: %{
          store_messages?: boolean(),
          subscribed?: boolean(),
          # for simplicity, only hold one buffer for everything. This may lead to
          # problems if a few sources are really noisy, they will force out
          # the other messages. We can deal with that later with a smaller
          # buffer per source, and the added complexity of having to limit
          # that total size
          buffer: BQ.t(Messaging.message())
        }

  @type state :: %{
          user: T.user(),
          mon_ref: reference(),
          conn_pid: pid() | nil,
          matchmaking: matchmaking_state(),
          messaging_state: messaging_state()
        }

  # TODO: would be better to have that as a db setting, perhaps passed as an
  # argument to init()
  @messaging_buffer_size 200

  @impl true
  def init({conn_pid, user}) do
    ref = Process.monitor(conn_pid)
    Logger.metadata(user_id: user.id)

    state = %{
      user: user,
      mon_ref: ref,
      conn_pid: conn_pid,
      matchmaking: initial_matchmaking_state(),
      messaging_state: %{
        store_messages?: true,
        subscribed?: false,
        buffer: BQ.new(@messaging_buffer_size)
      }
    }

    Logger.debug("init session #{inspect(self())}")
    Logger.info("session started")

    {:ok, state}
  end

  defp initial_matchmaking_state() do
    :no_matchmaking
  end

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
    GenServer.call(via_tuple(user_id), {:matchmaking, {:join_queues, queue_ids}})
  end

  @doc """
  Leave all the queues, and effectively removes the player from any matchmaking
  """
  @spec leave_queues(T.userid()) :: Matchmaking.leave_result()
  def leave_queues(user_id) do
    GenServer.call(via_tuple(user_id), {:matchmaking, :leave_queues})
  end

  @doc """
  A match has been found and the player is expected to ready up
  """
  @spec matchmaking_notify_found(T.userid(), Matchmaking.queue_id(), pid(), timeout()) :: :ok
  def matchmaking_notify_found(user_id, queue_id, room_pid, timeout_ms) do
    GenServer.cast(
      via_tuple(user_id),
      {:matchmaking, {:notify_found, queue_id, room_pid, timeout_ms}}
    )
  end

  @doc """
  The player is ready for the match
  """
  @spec matchmaking_ready(T.userid()) :: :ok | {:error, :no_match}
  def matchmaking_ready(user_id) do
    GenServer.call(via_tuple(user_id), {:matchmaking, :ready})
  end

  @spec matchmaking_lost(T.userid(), Matchmaking.lost_reason()) :: :ok
  def matchmaking_lost(user_id, reason) do
    GenServer.cast(via_tuple(user_id), {:matchmaking, {:lost, reason}})
  end

  @spec matchmaking_found_update(T.userid(), non_neg_integer(), pid()) :: :ok
  def matchmaking_found_update(user_id, ready_count, room_pid) do
    GenServer.cast(via_tuple(user_id), {:matchmaking, {:found_update, ready_count, room_pid}})
  end

  @spec battle_start(T.userid(), Teiserver.Autohost.start_response()) :: :ok
  def battle_start(user_id, battle_start_data) do
    GenServer.cast(via_tuple(user_id), {:battle_start, battle_start_data})
  end

  @doc """
  this user should now receive all messaging events
  """
  @spec subscribe_received(
          user_id :: T.userid(),
          since :: :latest | :from_start | {:marker, term()}
        ) :: {:ok, has_missed_messages :: boolean(), msg_to_send :: [Messaging.message()]}
  def subscribe_received(user_id, since) do
    GenServer.call(via_tuple(user_id), {:messaging, {:subscribe, since}})
  end

  @doc """
  Attempt to send a dm to the target player. If there is no session for this
  player the message is lost
  """
  @spec send_dm(T.userid(), Messaging.message()) :: :ok
  def send_dm(user_id, message) do
    GenServer.cast(via_tuple(user_id), {:messaging, {:dm, message}})
  end

  @doc """
  notify the connected player that they received a new friend request.
  If the player isn't connected it's a no-op. They'll get the friend request
  as part of the friend/list response next time they connect.
  """
  @spec friend_request_received(target_id :: T.userid(), originator_id :: T.userid()) :: :ok
  def friend_request_received(target_id, originator_id) do
    GenServer.cast(via_tuple(target_id), {:friend, {:request_received, originator_id}})
  end

  def start_link({_conn_pid, user} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(user.id))
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
  def handle_call({:replace, new_conn_pid}, _from, state) do
    Process.demonitor(state.mon_ref, [:flush])

    mon_ref = Process.monitor(new_conn_pid)
    Logger.info("session reused")

    {:reply, :ok, %{state | conn_pid: new_conn_pid, mon_ref: mon_ref}}
  end

  def handle_call(:conn_state, _from, state) do
    result = if is_nil(state.conn_pid), do: :reconnecting, else: :connected
    {:reply, result, state}
  end

  def handle_call(:disconnect, _from, state) do
    user_id = state.user.id

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
  def handle_call({:matchmaking, {:join_queues, []}}, _from, state),
    do: {:reply, {:error, :invalid_request}, state}

  def handle_call({:matchmaking, {:join_queues, queue_ids}}, _from, state) do
    case state.matchmaking do
      :no_matchmaking ->
        case join_all_queues(state.user.id, queue_ids, []) do
          :ok ->
            new_mm_state = {:searching, %{joined_queues: queue_ids}}
            {:reply, :ok, put_in(state.matchmaking, new_mm_state)}

          {:error, err} ->
            {:reply, {:error, err}, state}
        end

      {:searching, _} ->
        {:reply, {:error, :already_queued}, state}

      {:pairing, _} ->
        {:reply, {:error, :already_queued}, state}
    end
  end

  def handle_call({:matchmaking, :leave_queues}, _from, state) do
    case state.matchmaking do
      :no_matchmaking ->
        {:reply, {:error, :not_queued}, state}

      {:searching, %{joined_queues: joined_queues}} ->
        new_state = leave_all_queues(joined_queues, state)
        {:reply, :ok, new_state}

      {:pairing, %{room: {_, room_ref}} = pairing_state} ->
        Process.demonitor(room_ref, [:flush])
        queues_to_leave = [pairing_state.paired_queue | pairing_state.frozen_queues]
        new_state = leave_all_queues(queues_to_leave, state)
        {:reply, :ok, new_state}
    end
  end

  def handle_call({:matchmaking, :ready}, _from, state) do
    case state.matchmaking do
      {:pairing, %{room: {room_pid, _}} = pairing_state} ->
        password = :crypto.strong_rand_bytes(16) |> Base.encode16()

        data = %{
          user_id: state.user.id,
          name: state.user.name,
          password: password
        }

        new_state = %{
          state
          | matchmaking:
              {:pairing, %{pairing_state | readied: true} |> Map.put(:battle_password, password)}
        }

        {:reply, Matchmaking.ready(room_pid, data), new_state}

      _ ->
        {:reply, {:error, :no_match}, state}
    end
  end

  def handle_call({:messaging, {:subscribe, since}}, _from, state) do
    state =
      state
      |> put_in([:messaging_state, :subscribed?], true)
      |> put_in([:messaging_state, :store_messages?], true)

    buffer = state.messaging_state.buffer

    # Keep the history, even if it is sent to the player. This may be a
    # problem in the long run because the buffer are never emptied, but for
    # now it’ll do
    {msg_to_send, has_missed_messages} =
      case since do
        :latest ->
          {[], false}

        :from_start ->
          {BQ.to_list(buffer), BQ.dropped?(buffer)}

        {:marker, :invalid} ->
          {BQ.to_list(buffer), true}

        {:marker, marker} ->
          {seen, not_seen} = BQ.split_when(buffer, fn msg -> msg.marker == marker end)

          if is_nil(not_seen) do
            {BQ.to_list(seen), true}
          else
            {BQ.to_list(not_seen), false}
          end
      end

    {:reply, {:ok, has_missed_messages, msg_to_send}, state}
  end

  @impl true
  def handle_cast(
        {:matchmaking, {:notify_found, queue_id, room_pid, timeout_ms}},
        %{matchmaking: {:searching, %{joined_queues: queue_ids}}} = state
      ) do
    if not Enum.member?(queue_ids, queue_id) do
      {:noreply, state}
    else
      state = send_to_player({:matchmaking, {:notify_found, queue_id, timeout_ms}}, state)

      other_queues =
        for qid <- queue_ids, qid != queue_id do
          Matchmaking.leave_queue(qid, state.user.id)
          qid
        end

      room_ref = Process.monitor(room_pid)

      new_mm_state =
        {:pairing,
         %{
           paired_queue: queue_id,
           room: {room_pid, room_ref},
           frozen_queues: other_queues,
           readied: false
         }}

      new_state = Map.put(state, :matchmaking, new_mm_state)
      {:noreply, new_state}
    end
  end

  def handle_cast({:matchmaking, {:notify_found, _queue_id, room_pid, _}}, state) do
    # we're not searching anything. This can happen as a race when two queues
    # match the same player at the same time.
    # Do log it since it should not happen too often unless something is wrong
    Logger.info("Got a matchmaking found but in state #{inspect(state.matchmaking)}")

    Matchmaking.cancel(room_pid, state.user.id)
    {:noreply, state}
  end

  def handle_cast({:matchmaking, {:lost, reason}}, state) do
    case state.matchmaking do
      :no_matchmaking ->
        {:noreply, state}

      {:searching, _} ->
        state = send_to_player({:matchmaking, :notify_lost}, state)
        {:noreply, state}

      {:pairing,
       %{paired_queue: q_id, room: {_, ref}, frozen_queues: frozen_queues, readied: readied}} ->
        Process.demonitor(ref, [:flush])
        q_ids = [q_id | frozen_queues]
        state = send_to_player({:matchmaking, :notify_lost}, state)

        case reason do
          :timeout when not readied ->
            state = leave_all_queues(q_ids, state)
            state = send_to_player({:matchmaking, {:cancelled, reason}}, state)
            {:noreply, state}

          {:server_error, _details} ->
            state = leave_all_queues(q_ids, state)
            state = send_to_player({:matchmaking, {:cancelled, reason}}, state)
            {:noreply, state}

          _ ->
            case join_all_queues(state.user.id, q_ids, []) do
              :ok ->
                new_mm_state = {:searching, %{joined_queues: q_ids}}
                {:noreply, put_in(state.matchmaking, new_mm_state)}

              {:error, _err} ->
                state = send_to_player({:matchmaking, {:cancelled, :server_error}}, state)
                {:noreply, %{state | matchmaking: initial_matchmaking_state()}}
            end
        end
    end
  end

  def handle_cast({:matchmaking, {:found_update, current, room_pid}}, state) do
    case state.matchmaking do
      {:pairing, %{room: {^room_pid, _}}} ->
        {:noreply, send_to_player({:matchmaking, {:found_update, current}}, state)}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:battle_start, battle_start_data}, state) do
    case state.matchmaking do
      {:pairing, %{readied: true, battle_password: pass, room: {_pid, mon_ref}}} ->
        data = %{
          username: state.user.name,
          password: pass,
          ip: hd(battle_start_data.ips),
          port: battle_start_data.port,
          engine: battle_start_data.engine,
          game: battle_start_data.game,
          map: battle_start_data.map
        }

        state = send_to_player({:battle_start, data}, state)
        Process.demonitor(mon_ref, [:flush])
        {:noreply, %{state | matchmaking: :no_matchmaking}}

      _ ->
        Logger.warning(
          "User received a request to start a battle but is not in a state to do so #{inspect(state)}"
        )

        {:noreply, state}
    end
  end

  def handle_cast({:messaging, {:dm, message}}, state) do
    state =
      if state.messaging_state.store_messages? do
        update_in(state.messaging_state.buffer, fn buf -> BQ.put(buf, message) end)
      else
        state
      end

    case {state.messaging_state.subscribed?, state.conn_pid} do
      {true, pid} when not is_nil(pid) ->
        send(pid, {:messaging, {:dm_received, message}})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:friend, {:request_received, from_id}}, state) do
    state = send_to_player({:friend, {:request_received, from_id}}, state)
    {:noreply, state}
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _reason}, state) when ref == state.mon_ref do
    # we don't care about cancelling the timer if the player reconnects since reconnection
    # should be fairly low (and rate limited) so too many messages isn't an issue
    {:ok, _} = :timer.send_after(2_000, :player_timeout)
    Logger.info("Player disconnected abruptly")

    state =
      state
      |> Map.put(:conn_pid, nil)
      |> put_in([:messaging_state, :subscribed?], false)

    {:noreply, state}
  end

  def handle_info({:DOWN, ref, :process, _obj, reason}, state) do
    case state do
      %{matchmaking: {:pairing, %{room: {_, ^ref}}}} ->
        # only log in case of abnormal exit. If the queue itself goes down, so be it
        if reason != :normal, do: Logger.warning("Pairing room went down #{inspect(reason)}")
        # TODO tachyon_mvp: rejoin the room and send `lost` event
        # For now, just abruptly stop everything
        {:stop, :normal, state}

      st ->
        if reason not in [:normal, :test_cleanup] do
          Logger.warning(
            "unhandled DOWN: #{inspect(ref)} went down because #{reason}. state: #{inspect(st)}"
          )
        end

        {:noreply, state}
    end
  end

  def handle_info(:player_timeout, state) do
    if is_nil(state.conn_pid) do
      Logger.debug("Player timed out, stopping session")
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

  defp leave_all_queues(queues_to_leave, state) do
    # TODO tachyon_mvp: leaving queue ignore failure there.
    # It is a bit unclear what kind of failure can happen, and also
    # what should be done in that case
    Enum.each(queues_to_leave, fn qid ->
      Matchmaking.leave_queue(qid, state.user.id)
    end)

    Map.put(state, :matchmaking, initial_matchmaking_state())
  end

  defp send_to_player(message, state) do
    # TODO tachyon_mvp: what should server do if the connection is down at that time?
    # The best is likely to store it and send the notification upon reconnection
    if state.conn_pid != nil do
      send(state.conn_pid, message)
    end

    state
  end
end
