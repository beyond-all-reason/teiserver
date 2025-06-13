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
  alias Teiserver.{Account, Matchmaking, Messaging, Party, Player}
  alias Teiserver.TachyonBattle
  alias Teiserver.Helpers.BoundedQueue, as: BQ
  alias Phoenix.PubSub
  alias Teiserver.Helpers.MonitorCollection, as: MC

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
               room: pid(),
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

  @type party_state :: %{
          # the last party state version gotten from the party through GenServer.call
          # this is used to avoid races where the reply of the call would be processed
          # before a message already in the mailbox
          version: integer(),
          current_party: Party.id(),
          invited_to: [{integer(), Party.id()}]
        }

  @type battle_state ::
          nil
          | %{
              id: TachyonBattle.id()
            }

  @type state :: %{
          user: T.user(),
          monitors: MC.t(),
          mon_ref: reference(),
          conn_pid: pid() | nil,
          matchmaking: matchmaking_state(),
          messaging_state: messaging_state(),
          party: party_state(),
          user_subscriptions: MapSet.t(T.userid()),
          battle: battle_state()
        }

  # TODO: would be better to have that as a db setting, perhaps passed as an
  # argument to init()
  @messaging_buffer_size 200

  def start_link({_conn_pid, user} = arg) do
    GenServer.start_link(__MODULE__, arg, name: via_tuple(user.id))
  end

  @impl true
  def init({conn_pid, user}) do
    Logger.metadata(actor_type: :session, user_id: user.id)
    monitors = MC.monitor(MC.new(), conn_pid, :connection)

    state = %{
      user: user,
      monitors: monitors,
      conn_pid: conn_pid,
      matchmaking: initial_matchmaking_state(),
      messaging_state: %{
        store_messages?: true,
        subscribed?: false,
        buffer: BQ.new(@messaging_buffer_size)
      },
      user_subscriptions: MapSet.new(),
      party: initial_party_state(),
      battle: nil
    }

    broadcast_user_update!(user, :menu)

    Logger.debug("init session #{inspect(self())}")
    Logger.info("session started")

    {:ok, state}
  end

  defp initial_matchmaking_state() do
    :no_matchmaking
  end

  ################################################################################
  #                                                                              #
  #                                    API                                       #
  #                                                                              #
  ################################################################################

  @doc """
  Retrieve the connection state for the given user
  """
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

  @spec join_queues(T.userid(), [Matchmaking.queue_id()]) :: :ok | Matchmaking.join_error()
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

  @spec matchmaking_notify_lost(T.userid(), Matchmaking.lost_reason()) :: :ok
  def matchmaking_notify_lost(user_id, reason) do
    GenServer.cast(via_tuple(user_id), {:matchmaking, {:lost, reason}})
  end

  @spec matchmaking_notify_cancelled(T.userid(), Matchmaking.cancelled_reason()) :: :ok
  def matchmaking_notify_cancelled(user_id, reason) do
    GenServer.cast(via_tuple(user_id), {:matchmaking, {:cancelled, reason}})
  end

  @spec matchmaking_found_update(T.userid(), non_neg_integer(), pid()) :: :ok
  def matchmaking_found_update(user_id, ready_count, room_pid) do
    GenServer.cast(via_tuple(user_id), {:matchmaking, {:found_update, ready_count, room_pid}})
  end

  @doc """
  Let the player know that they are now in a battle
  """
  @spec battle_start(T.userid(), {TachyonBattle.id(), pid()}, Teiserver.Autohost.start_response()) ::
          :ok
  def battle_start(user_id, battle_data, battle_start_data) do
    GenServer.cast(via_tuple(user_id), {:battle, {:start, battle_data, battle_start_data}})
  end

  @doc """
  notify the teiserver side that the player left a battle. This is coming
  from the engine
  """
  @spec notify_battle_left(T.userid(), TachyonBattle.id()) :: :ok
  def notify_battle_left(user_id, battle_id) do
    GenServer.cast(via_tuple(user_id), {:battle, {:left, battle_id}})
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

  @spec send_party_message(T.userid(), String.t()) :: :ok | {:error, reason :: term()}
  def send_party_message(user_id, message_content) do
    GenServer.call(via_tuple(user_id), {:messaging, {:send_party_message, message_content}})
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

  @doc """
  notify the connected player that a pending friend request has been cancelled
  If the player isn't connected it's a no-op.
  """
  @spec friend_request_cancelled(target_id :: T.userid(), originator_id :: T.userid()) :: :ok
  def friend_request_cancelled(target_id, originator_id) do
    GenServer.cast(via_tuple(target_id), {:friend, {:request_cancelled, originator_id}})
  end

  @doc """
  notify the connected originator player that their friend request
  has been accepted by the target.
  """
  @spec friend_request_accepted(originator_id :: T.userid(), target_id :: T.userid()) :: :ok
  def friend_request_accepted(originator_id, target_id) do
    GenServer.cast(via_tuple(originator_id), {:friend, {:request_accepted, target_id}})
  end

  @doc """
  notify the connected originator player that their friend request
  has been rejected by the target.
  """
  @spec friend_request_rejected(originator_id :: T.userid(), target_id :: T.userid()) :: :ok
  def friend_request_rejected(originator_id, target_id) do
    GenServer.cast(via_tuple(originator_id), {:friend, {:request_rejected, target_id}})
  end

  @doc """
  notify the connected player that they have been removed from a friendlist
  by the given user
  """
  @spec friend_request_rejected(user_id :: T.userid(), from_id :: T.userid()) :: :ok
  def friend_removed(user_id, from_id) do
    GenServer.cast(via_tuple(user_id), {:friend, {:removed, from_id}})
  end

  @doc """
  To forcefully disconnect a connected player and replace this connection
  with another one. This is to avoid having the same player with several
  connections.
  """
  @spec replace_connection(pid(), pid()) ::
          {:ok, session_state :: %{party: party_state()}} | :died
  def replace_connection(sess_pid, new_conn_pid) do
    GenServer.call(sess_pid, {:replace, new_conn_pid})
  catch
    :exit, _ ->
      :died
  end

  @doc """
  Subscribe the session process to user updates. This will also ensure the first
  message processed from these channel is the full user state
  """
  @spec subscribe_updates(T.userid(), [T.userid()]) :: :ok | {:error, {:invalid_ids, [integer()]}}
  def subscribe_updates(originator_id, user_ids) do
    GenServer.call(via_tuple(originator_id), {:user, {:subscribe_updates, user_ids}})
  end

  @spec unsubscribe_updates(T.userid(), [T.userid()]) ::
          :ok | {:error, {:invalid_ids, [integer()]}}
  def unsubscribe_updates(originator_id, user_ids) do
    GenServer.call(via_tuple(originator_id), {:user, {:unsubscribe_updates, user_ids}})
  end

  @doc """
  get the transient user public infos like status (playing/menu ...)
  """
  def get_user_info(user_id) do
    GenServer.call(via_tuple(user_id), {:user, :get_info})
  catch
    :exit, _ ->
      %{status: :offline}
  end

  @spec create_party(T.userid()) ::
          {:ok, Party.id()} | {:error, :already_in_party} | {:error, reason :: term()}
  def create_party(user_id) do
    GenServer.call(via_tuple(user_id), {:party, :create})
  end

  @spec leave_party(T.userid()) :: :ok | {:error, :not_a_member} | {:error, reason :: term()}
  def leave_party(user_id) do
    GenServer.call(via_tuple(user_id), {:party, :leave})
  end

  @spec invite_to_party(T.userid(), T.userid()) ::
          :ok | {:error, :not_in_a_party | :already_invited | :invalid_player | :timeout}
  def invite_to_party(user_id, invited_user_id) do
    GenServer.call(via_tuple(user_id), {:party, {:invite, invited_user_id}})
  end

  @spec accept_invite_to_party(T.userid(), Party.id()) ::
          :ok | {:error, :not_in_a_party | :not_invited}
  def accept_invite_to_party(user_id, party_id) do
    GenServer.call(via_tuple(user_id), {:party, {:accept_invite, party_id}})
  end

  @spec decline_invite_to_party(T.userid(), Party.id()) ::
          :ok | {:error, :not_in_a_party | :not_invited}
  def decline_invite_to_party(user_id, party_id) do
    GenServer.call(via_tuple(user_id), {:party, {:decline_invite, party_id}})
  end

  @spec cancel_invite_to_party(T.userid(), T.userid()) ::
          :ok | {:error, :not_in_a_party | :not_invited}
  def cancel_invite_to_party(user_id, invited_user_id) do
    GenServer.call(via_tuple(user_id), {:party, {:cancel_invite, invited_user_id}})
  end

  @spec kick_party_member(actor_id :: T.userid(), target_id :: T.userid()) ::
          :ok | {:error, :invalid_party | :invalid_target | :not_a_member}
  def kick_party_member(actor_id, target_id) do
    GenServer.call(via_tuple(actor_id), {:party, {:kick_player, target_id}})
  end

  @spec party_notify_invited(T.userid(), Party.state()) :: :ok
  def party_notify_invited(user_id, party_state) do
    GenServer.cast(via_tuple(user_id), {:party, {:invited, party_state}})
  end

  @spec party_notify_updated(T.userid(), Party.state()) :: :ok
  def party_notify_updated(user_id, party_state) do
    GenServer.cast(via_tuple(user_id), {:party, {:updated, party_state}})
  end

  @spec party_notify_removed(T.userid(), Party.state()) :: :ok
  def party_notify_removed(user_id, party_state) do
    GenServer.cast(via_tuple(user_id), {:party, {:removed, party_state}})
  end

  @spec party_notify_join_queues(T.userid(), [Matchmaking.queue_id()], Party.state()) :: :ok
  def party_notify_join_queues(user_id, queues, party_state) do
    GenServer.cast(via_tuple(user_id), {:party, {:join_queues, queues, party_state}})
  end

  ################################################################################
  #                                                                              #
  #                       INTERNAL MESSAGE HANDLERS                              #
  #                                                                              #
  ################################################################################

  @impl true
  def handle_call({:replace, new_conn_pid}, _from, state) do
    monitors = MC.demonitor_by_val(state.monitors, :connection, [:flush])
    Logger.info("session reused")

    {current_party, invited_to} = get_party_states(state.party)

    party_state = %{
      version: if(current_party == nil, do: nil, else: current_party.version),
      current_party: if(current_party == nil, do: nil, else: current_party.id),
      invited_to: Enum.map(invited_to, fn st -> {st.version, st.id} end)
    }

    new_state = %{state | conn_pid: new_conn_pid, monitors: monitors, party: party_state}

    party = %{party: current_party, invited_to_parties: invited_to}
    {:reply, {:ok, party}, new_state}
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

    broadcast_user_update!(state.user, :offline)

    {:stop, :normal, :ok, %{state | matchmaking: initial_matchmaking_state()}}
  end

  # this should never happen because the json schema already checks for minimum length
  def handle_call({:matchmaking, {:join_queues, []}}, _from, state),
    do: {:reply, {:error, :invalid_request}, state}

  def handle_call({:matchmaking, {:join_queues, queue_ids}}, _from, state) do
    case state.matchmaking do
      :no_matchmaking ->
        case state.party.current_party do
          nil ->
            case join_matchmaking(queue_ids, state) do
              {:ok, new_state} ->
                {:reply, :ok, new_state}

              {:error, err} ->
                {:reply, {:error, err}, state}
            end

          party_id ->
            with :ok <- Party.join_queues(party_id, queue_ids),
                 {:ok, new_state} <- join_matchmaking(queue_ids, state) do
              {:reply, :ok, new_state}
            else
              {:error, reason} -> {:reply, {:error, reason}, state}
            end
        end

      {:searching, _} ->
        {:reply, {:error, :already_queued}, state}

      {:pairing, _} ->
        {:reply, {:error, :already_queued}, state}
    end
  end

  def handle_call({:matchmaking, :leave_queues}, _from, state) do
    {resp, state} = leave_matchmaking(state)
    {:reply, resp, state}
  end

  def handle_call({:matchmaking, :ready}, _from, state) do
    case state.matchmaking do
      {:pairing, %{room: room_pid} = pairing_state} ->
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

  def handle_call({:messaging, {:send_party_message, _message_content}}, _from, state)
      when state.party.current_party == nil,
      do: {:reply, {:error, "not in party"}}

  def handle_call({:messaging, {:send_party_message, message_content}}, _from, state) do
    case Party.send_message(state.party.current_party, state.user.id, message_content) do
      :ok -> {:reply, :ok, state}
      {:error, :invalid_request, reason} -> {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:user, {:subscribe_updates, user_ids}}, _from, state) do
    users = Account.query_users(where: [id_in: user_ids])

    if Enum.count(users) != Enum.count(user_ids) do
      diff =
        MapSet.difference(MapSet.new(user_ids), MapSet.new(Enum.map(users, & &1.id)))
        |> MapSet.to_list()

      {:reply, {:error, {:invalid_ids, diff}}, state}
    else
      Enum.each(users, &do_subscribe_updates/1)
      new_state = Map.update!(state, :user_subscriptions, &MapSet.union(&1, MapSet.new(user_ids)))
      {:reply, :ok, new_state}
    end
  end

  def handle_call({:user, {:unsubscribe_updates, user_ids}}, _from, state) do
    user_ids = MapSet.new(user_ids)
    to_remove = MapSet.intersection(user_ids, state.user_subscriptions)

    for user_id <- to_remove do
      PubSub.unsubscribe(Teiserver.PubSub, user_topic(user_id))
    end

    new_subs = MapSet.difference(state.user_subscriptions, user_ids)
    {:reply, :ok, %{state | user_subscriptions: new_subs}}
  end

  def handle_call({:user, :get_info}, _from, state) do
    status =
      cond do
        state.battle != nil -> :playing
        true -> :menu
      end

    {:reply, %{status: status}, state}
  end

  def handle_call({:party, :create}, _from, state)
      when state.party.current_party != nil,
      do: {:reply, {:error, :already_in_party}, state}

  def handle_call({:party, :create}, _from, state) do
    case Party.create_party(state.user.id) do
      {:ok, party_id, pid} ->
        state =
          state
          |> put_in([:party, :current_party], party_id)
          |> Map.update!(:monitors, &MC.monitor(&1, pid, :current_party))

        case leave_matchmaking(state) do
          {:ok, state} ->
            state = send_to_player(state, {:matchmaking, {:cancelled, :intentional}})
            {:reply, {:ok, party_id}, state}

          _ ->
            {:reply, {:ok, party_id}, state}
        end

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:party, :leave}, _from, state)
      when is_nil(state.party.current_party),
      do: {:reply, {:error, :not_in_party}, state}

  def handle_call({:party, :leave}, _from, state) do
    party_id = state.party.current_party

    case Teiserver.Party.leave_party(state.party.current_party, state.user.id) do
      :ok ->
        state =
          state
          |> put_in([:party, :current_party], nil)
          |> Map.update!(:monitors, &MC.demonitor_by_val(&1, :current_party))

        {left_mm?, state} =
          leave_matchmaking(state)

        state =
          if left_mm? == :ok,
            do: send_to_player(state, {:matchmaking, {:cancelled, :party_user_left}}),
            else: state

        {:reply, :ok, state}

      {:error, :not_a_member} ->
        {:reply, :ok, %{state | party: initial_party_state()}}

      {:error, reason} ->
        {:reply, {:error, {party_id, reason}}, state}
    end
  end

  def handle_call({:party, {:invite, _}}, _from, state)
      when is_nil(state.party.current_party),
      do: {:reply, {:error, :not_in_party}, state}

  def handle_call({:party, {:invite, user_id}}, _from, state) do
    # go through the other session as well to ensure valid and connected player
    msg = {:party, {:invite, state.party.current_party, user_id}}

    try do
      case GenServer.call(via_tuple(user_id), msg) do
        :ok -> {:reply, :ok, state}
        {:error, reason} -> {:reply, {:error, reason}, state}
      end

      # it is very unlikely that both sessions will call each other at the same time
      # but if that happens, they will deadlock then timeout
      # catch that and error out, it's better than crashing the session
    catch
      :exit, {:timeout, _} -> {:reply, {:error, :timeout}}
    end
  catch
    :exit, {:noproc, _} ->
      {:reply, {:error, :invalid_player}, state}
  end

  def handle_call({:party, {:invite, party_id, invited_id}}, _from, state) do
    case Party.create_invite(party_id, invited_id) do
      {:ok, party_state} ->
        state =
          state
          |> update_in([:party, :invited_to], fn invited ->
            [{party_state.version, party_state.id} | invited]
          end)
          |> Map.update!(
            :monitors,
            &MC.monitor(&1, party_state.pid, {:invited_to_party, party_id})
          )

        send_to_player!({:party, {:invited, party_state}}, state)
        {:reply, :ok, state}

      {:error, reason} ->
        {:reply, {:error, reason}, state}
    end
  end

  def handle_call({:party, {:accept_invite, party_id}}, _from, state) do
    case Party.accept_invite(party_id, state.user.id) do
      {:ok, party_state} ->
        state =
          state
          |> update_in([:party, :invited_to], fn invited ->
            Enum.filter(invited, fn {_version, p_id} -> p_id != party_id end)
          end)
          |> put_in([:party, :current_party], party_state.id)
          |> put_in([:party, :version], party_state.version)

        case leave_matchmaking(state) do
          {:ok, state} ->
            state = send_to_player(state, {:matchmaking, {:cancelled, :intentional}})
            {:reply, :ok, state}

          _ ->
            {:reply, :ok, state}
        end

      {:error, _reason} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:party, {:decline_invite, party_id}}, _from, state) do
    case Party.decline_invite(party_id, state.user.id) do
      {:ok, party_state} ->
        state =
          state
          |> update_in([:party, :invited_to], fn invited ->
            Enum.filter(invited, fn {_version, p_id} -> p_id != party_id end)
          end)
          |> put_in([:party, :version], party_state.version)

        {:reply, :ok, state}

      {:error, _reason} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:party, {:cancel_invite, _invited_user_id}}, _from, state)
      when state.party.current_party == nil do
    {:reply, {:error, :not_in_party}, state}
  end

  def handle_call({:party, {:cancel_invite, invited_user_id}}, _from, state) do
    party_id = state.party.current_party

    case Party.cancel_invite(party_id, invited_user_id) do
      {:ok, party_state} ->
        state = state |> put_in([:party, :version], party_state.version)

        {:reply, :ok, state}

      {:error, _reason} = err ->
        {:reply, err, state}
    end
  end

  def handle_call({:party, {:kick_player, _}}, _from, state)
      when state.party.current_party == nil do
    {:reply, {:error, :not_in_party}, state}
  end

  def handle_call({:party, {:kick_player, target_id}}, _from, state) do
    party_id = state.party.current_party

    case Party.kick_user(party_id, state.user.id, target_id) do
      {:ok, party_state} ->
        state = state |> put_in([:party, :version], party_state.version)

        {:reply, :ok, state}

      {:error, _} = err ->
        {:reply, err, state}
    end
  end

  @impl true
  def handle_cast(
        {:matchmaking, {:notify_found, queue_id, room_pid, timeout_ms}},
        %{matchmaking: {:searching, %{joined_queues: joined}}} = state
      ) do
    if Enum.find(joined, &(&1 == queue_id)) == nil do
      {:noreply, state}
    else
      state = send_to_player(state, {:matchmaking, {:notify_found, queue_id, timeout_ms}})

      {[paired_queue], other_queues} =
        Enum.split_with(joined, fn qid -> qid == queue_id end)

      monitors =
        Enum.reduce(other_queues, state.monitors, fn qid, monitors ->
          Matchmaking.leave_queue(qid, state.user.id)
          MC.demonitor_by_val(monitors, {:mm_queue, qid}, [:flush])
        end)

      monitors = MC.monitor(monitors, room_pid, :mm_room)

      new_mm_state =
        {:pairing,
         %{
           paired_queue: paired_queue,
           room: room_pid,
           frozen_queues: other_queues,
           readied: false
         }}

      new_state =
        state |> Map.put(:matchmaking, new_mm_state) |> Map.replace!(:monitors, monitors)

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
        state = send_to_player(state, {:matchmaking, {:notify_lost, reason}})
        {:noreply, state}

      {:pairing,
       %{
         paired_queue: q_id,
         room: _room_pid,
         frozen_queues: frozen_queues,
         readied: readied
       }} ->
        monitors =
          state.monitors
          |> MC.demonitor_by_val(:mm_room, [:flush])
          |> MC.demonitor_by_val({:mm_queue, q_id})

        state = Map.replace!(state, :monitors, monitors)

        q_ids = [q_id | frozen_queues]

        case reason do
          :timeout when not readied ->
            state =
              leave_all_queues(q_ids, state)
              |> send_to_player({:matchmaking, :notify_lost})
              |> send_to_player({:matchmaking, {:cancelled, reason}})

            {:noreply, state}

          {:server_error, _details} ->
            state =
              leave_all_queues(q_ids, state)
              |> send_to_player({:matchmaking, :notify_lost})
              |> send_to_player({:matchmaking, {:cancelled, reason}})

            {:noreply, state}

          _ ->
            state = send_to_player(state, {:matchmaking, :notify_lost})

            case join_matchmaking(q_ids, state) do
              {:ok, new_state} ->
                {:noreply, new_state}

              {:error, _err} ->
                state = send_to_player(state, {:matchmaking, {:cancelled, :server_error}})
                {:noreply, %{state | matchmaking: initial_matchmaking_state()}}
            end
        end
    end
  end

  def handle_cast({:matchmaking, {:cancelled, reason}}, state) do
    case leave_matchmaking(state) do
      {:ok, state} ->
        state = send_to_player(state, {:matchmaking, {:cancelled, reason}})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:matchmaking, {:found_update, current, room_pid}}, state) do
    case state.matchmaking do
      {:pairing, %{room: ^room_pid}} ->
        {:noreply, send_to_player(state, {:matchmaking, {:found_update, current}})}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:battle, {:start, {battle_id, battle_pid}, battle_start_data}}, state) do
    Logger.info("entering battle #{battle_id}")

    case state.matchmaking do
      {:pairing, %{readied: true, battle_password: pass, room: _room_pid}} ->
        data = %{
          username: state.user.name,
          password: pass,
          ip: hd(battle_start_data.ips),
          port: battle_start_data.port,
          engine: battle_start_data.engine,
          game: battle_start_data.game,
          map: battle_start_data.map
        }

        state = send_to_player(state, {:battle_start, data})

        monitors =
          MC.demonitor_by_val(state.monitors, :mm_room, [:flush])
          |> MC.monitor(battle_pid, {:battle, battle_id})

        # TODO: this should ideally come from an engine event, but in first approximation it'll do
        broadcast_user_update!(state.user, :playing)

        {:noreply,
         %{state | matchmaking: :no_matchmaking, monitors: monitors, battle: %{id: battle_id}}}

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
        send(pid, {:messaging, {:received, message}})
        {:noreply, state}

      _ ->
        {:noreply, state}
    end
  end

  def handle_cast({:friend, {event, from_id}}, state)
      when event in [
             :request_received,
             :request_cancelled,
             :request_accepted,
             :request_rejected,
             :removed
           ] do
    state = send_to_player(state, {:friend, {event, from_id}})
    {:noreply, state}
  end

  def handle_cast({:user, :get_subscribe_state}, state) do
    broadcast_user_update!(state.user, :menu)
    {:noreply, state}
  end

  def handle_cast({:party, {:updated, party_state}}, state) do
    if (state.party.current_party == party_state.id && state.party.version <= party_state.version) ||
         Enum.any?(state.party.invited_to, fn {v, id} ->
           id == party_state.id && v <= party_state.version
         end),
       do: send_to_player!({:party, {:updated, party_state}}, state)

    {:noreply, state}
  end

  def handle_cast({:party, {:removed, party_state}}, state) do
    state =
      if party_state.id == state.party.current_party do
        send_to_player!({:party, {:removed, party_state.id}}, state)

        Map.update!(state, :party, fn st ->
          %{st | version: 0, current_party: nil}
        end)
      else
        case Enum.split_with(state.party.invited_to, fn {_v, id} -> party_state.id == id end) do
          # got a stray message, maybe the player already left
          {[], _} ->
            state

          {[_], rest} ->
            send_to_player!({:party, {:removed, party_state.id}}, state)
            put_in(state.party.invited_to, rest)
        end
      end

    {:noreply, state}
  end

  def handle_cast({:party, {:join_queues, _queues, party_state}}, state)
      when state.party.current_party != party_state.id,
      do: {:noreply, state}

  def handle_cast({:party, {:join_queues, queues, party_state}}, state) do
    case state.matchmaking do
      :no_matchmaking ->
        case join_matchmaking(queues, state) do
          {:ok, new_state} ->
            new_state =
              put_in(new_state.party.version, party_state.version)
              |> send_to_player({:matchmaking, {:queues_joined, queues}})

            {:noreply, new_state}

          {:error, err} ->
            Logger.error("party join queues #{inspect(queues)} but errored with #{inspect(err)}")
            raise "todo: cancel the matchmaking in the party, don't crash the genserver"
        end

      {:searching, qs} ->
        if MapSet.new(queues) == MapSet.new(qs.joined_queues) do
          # this happens for the player that initiated the queuing in the party
          # or when 2 players hit "queue" at the same time
          {:noreply, state}
        else
          Logger.error(
            "party join queues #{inspect(queues)} but already in matchmaking #{inspect(state.matchmaking)}"
          )

          {:stop, :crash, state}
        end

      _ ->
        Logger.error(
          "party join queues #{inspect(queues)} but already in matchmaking #{inspect(state.matchmaking)}"
        )

        {:stop, :crash, state}
    end
  end

  @impl true
  def handle_info({:DOWN, ref, :process, _, _reason}, state) do
    val = MC.get_val(state.monitors, ref)
    state = Map.update!(state, :monitors, &MC.demonitor_by_val(&1, val))

    case val do
      nil ->
        {:noreply, state}

      :connection ->
        # we don't care about cancelling the timer if the player reconnects since reconnection
        # should be fairly low (and rate limited) so too many messages isn't an issue
        {:ok, _} = :timer.send_after(2_000, :player_timeout)
        Logger.info("Player disconnected abruptly")

        state =
          state
          |> Map.put(:conn_pid, nil)
          |> put_in([:messaging_state, :subscribed?], false)

        {:noreply, state}

      {:mm_queue, queue_id} ->
        case state do
          %{matchmaking: {:searching, %{joined_queues: joined}}} ->
            case Enum.find(joined, &(&1 == queue_id)) do
              nil ->
                {:noreply, state}

              _ ->
                state =
                  leave_all_queues(joined, state)
                  |> send_to_player({:matchmaking, {:cancelled, :server_error}})

                {:noreply, state}
            end

          %{matchmaking: {:pairing, %{paired_queue: ^queue_id} = pairing_st}} ->
            state =
              leave_all_queues([pairing_st.paired_queue | pairing_st.frozen_queues], state)
              |> send_to_player({:matchmaking, {:cancelled, :server_error}})

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      :mm_room ->
        case state do
          %{matchmaking: {:pairing, %{paired_queue: _qid} = pairing_st}} ->
            state =
              leave_all_queues([pairing_st.paired_queue | pairing_st.frozen_queues], state)
              |> send_to_player({:matchmaking, {:cancelled, :server_error}})

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      :current_party ->
        case state do
          %{party: %{current_party: party_id}} ->
            send_to_player!({:party, {:removed, party_id}}, state)

            state =
              Map.update!(state, :party, fn st ->
                %{st | version: 0, current_party: nil}
              end)

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      {:invited_to_party, party_id} ->
        case Enum.split_with(state.party.invited_to, fn {_version, p_id} ->
               p_id == party_id
             end) do
          {[_], rest} ->
            send_to_player!({:party, {:removed, party_id}}, state)

            state =
              Map.update!(state, :party, fn st ->
                %{st | invited_to: rest}
              end)

            {:noreply, state}

          _ ->
            {:noreply, state}
        end

      {:battle, battle_id} ->
        Logger.info("battle #{battle_id} went down")
        broadcast_user_update!(state.user, :menu)
        {:noreply, %{state | battle: nil}}
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

  def handle_info(
        %{
          channel: "tachyon:user:" <> _user_id,
          user_id: user_id,
          event: :user_updated,
          state: user_state
        },
        state
      ) do
    state =
      if user_id in state.user_subscriptions do
        send_to_player(state, {:user, {:user_updated, user_state}})
      else
        state
      end

    {:noreply, state}
  end

  defp via_tuple(user_id) do
    Player.SessionRegistry.via_tuple(user_id)
  end

  # assume all checks have been done, and make the current player join
  # the specified queues, modifying the state accordingly and returning it
  defp join_matchmaking(queue_ids, state) do
    case join_all_queues(state.user.id, state.party.current_party, state.monitors, queue_ids, []) do
      {:ok, monitors, joined} ->
        new_mm_state = {:searching, %{joined_queues: joined}}

        new_state =
          state
          |> Map.replace!(:matchmaking, new_mm_state)
          |> Map.replace!(:monitors, monitors)

        {:ok, new_state}

      {:error, err} ->
        {:error, err}
    end
  end

  @spec join_all_queues(T.userid(), Party.id() | nil, MC.t(), [Matchmaking.queue_id()], [
          Matchmaking.queue_id()
        ]) ::
          {:ok, MC.t(), [Matchmaking.queue_id()]} | Matchmaking.join_error()
  defp join_all_queues(_user_id, _party_id, monitors, [], joined), do: {:ok, monitors, joined}

  defp join_all_queues(user_id, party_id, monitors, [to_join | rest], joined) do
    case Matchmaking.join_queue(to_join, user_id, party_id) do
      {:ok, queue_pid} ->
        monitors = MC.monitor(monitors, queue_pid, {:mm_queue, to_join})
        join_all_queues(user_id, party_id, monitors, rest, [to_join | joined])

      # the `queue` message is all or nothing, so if joining a later queue need
      # to leave the queues already joined
      {:error, reason} ->
        Enum.each(joined, fn qid ->
          Matchmaking.leave_queue(qid, user_id)
          MC.demonitor_by_val(monitors, {:mm_queue, qid}, [:flush])
        end)

        {:error, reason}
    end
  end

  defp leave_matchmaking(state) do
    case state.matchmaking do
      :no_matchmaking ->
        {{:error, :not_queued}, state}

      {:searching, %{joined_queues: joined_queues}} ->
        new_state = leave_all_queues(joined_queues, state)
        {:ok, new_state}

      {:pairing, %{room: _pid} = pairing_state} ->
        monitors = MC.demonitor_by_val(state.monitors, :mm_room, [:flush])
        queues_to_leave = [pairing_state.paired_queue | pairing_state.frozen_queues]
        new_state = leave_all_queues(queues_to_leave, state)
        {:ok, %{new_state | monitors: monitors}}
    end
  end

  defp leave_all_queues(queues_to_leave, state) do
    # TODO tachyon_mvp: leaving queue ignore failure there.
    # It is a bit unclear what kind of failure can happen, and also
    # what should be done in that case
    monitors =
      Enum.reduce(queues_to_leave, state.monitors, fn
        qid, monitors ->
          Matchmaking.leave_queue(qid, state.user.id)
          MC.demonitor_by_val(monitors, {:mm_queue, qid}, [:flush])
      end)

    state
    |> Map.replace!(:matchmaking, initial_matchmaking_state())
    |> Map.replace!(:monitors, monitors)
  end

  defp send_to_player(state, message) do
    # TODO tachyon_mvp: what should server do if the connection is down at that time?
    # The best is likely to store it and send the notification upon reconnection
    if state.conn_pid != nil do
      send(state.conn_pid, message)
    end

    state
  end

  @spec send_to_player!(term(), state()) :: :ok
  defp send_to_player!(message, state) do
    # this is the same as send_to_player, but doesn't persist the message if
    # there's no connection at that time.
    # This should be used for messages where there's another way to recover
    # state without having to rely on an interupted stream of events.
    # For example, player get full party state upon connection, so party events
    # can be not persisted
    if state.conn_pid != nil do
      send(state.conn_pid, message)
    end

    :ok
  end

  defp do_subscribe_updates(user) do
    topic = user_topic(user.id)
    :ok = PubSub.subscribe(Teiserver.PubSub, topic)

    case Player.SessionRegistry.lookup(user.id) do
      # player is offline, simulate the broadcast ourselves
      nil ->
        broadcast_user_update!(user, :offline)

      # TODO: needs to store a monitor in the state to handle the case where the
      # session dies before it can process this message.
      pid ->
        GenServer.cast(pid, {:user, :get_subscribe_state})
    end
  end

  defp user_topic(%{id: id}), do: user_topic(id)
  defp user_topic(user_id), do: "tachyon:user:#{user_id}"

  defp broadcast_user_update!(user, status) do
    topic = user_topic(user)

    state = %{
      user_id: user.id,
      username: user.name,
      clan_id: user.clan_id,
      # the user struct is a giant mess, where a bunch of stuff is added from
      # "user stats data" and whatnot. We should refactor user access so that
      # we get the same struct every time, possibly with nil values for some keys
      # but in the meantime, just defensively get the country
      country: Map.get(user, :country, "??"),
      status: status
    }

    PubSub.broadcast!(
      Teiserver.PubSub,
      topic,
      # for now(?) we don't surface the `reconnecting` status. I think we'll revisit
      # that because it's not a transparent state in term of capabilities:
      # the player is "online" but cannot vote, reply, or anything really
      %{
        channel: topic,
        event: :user_updated,
        user_id: user.id,
        state: state
      }
    )
  end

  defp initial_party_state(), do: %{version: 0, current_party: nil, invited_to: []}

  # Gather the state of all relevant parties for the given session
  defp get_party_states(party_state) do
    ids = [party_state.current_party | Enum.map(party_state.invited_to, fn {_, id} -> id end)]

    tasks =
      Enum.map(ids, fn id ->
        Task.async(fn ->
          if id == nil, do: nil, else: Party.get_state(id)
        end)
      end)

    [current | invited_to] = Task.await_many(tasks)
    {current, invited_to}
  end
end
