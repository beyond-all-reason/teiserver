defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  require Logger
  alias Teiserver.Tachyon.Schema
  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Account, Player, Matchmaking, Messaging}

  @behaviour Handler

  @type state :: %{
          user: T.user(),
          sess_monitor: reference(),
          pending_responses: Handler.pending_responses()
        }

  @impl Handler
  def connect(conn) do
    {a, b, c, d} = conn.remote_ip
    ipv4_address = "#{a}.#{b}.#{c}.#{d}"

    lobby_client = conn.assigns[:token].application.uid
    user = conn.assigns[:token].owner

    case Teiserver.CacheUser.tachyon_login(user, ipv4_address, lobby_client) do
      {:ok, user} ->
        {:ok, %{user: user}}

      {:error, :rate_limited, msg} ->
        {:error, 429, msg}

      {:error, msg} ->
        {:error, 403, msg}
    end
  end

  @impl Handler
  @spec init(%{user: T.user()}) :: Handler.result()
  def init(initial_state) do
    # this is inside the process that maintain the connection
    {:ok, session_pid, sess_state} = setup_session(initial_state.user)

    sess_monitor = Process.monitor(session_pid)

    state =
      initial_state |> Map.put(:sess_monitor, sess_monitor) |> Map.put(:pending_responses, %{})

    user = initial_state.user
    Logger.metadata(user_id: user.id)

    {friends, incoming, outgoing} = get_user_friends(state.user.id)

    event = %{
      user: %{
        userId: to_string(user.id),
        username: user.name,
        displayName: user.name,
        clanId: user.clan_id,
        countryCode: user.country,
        status: :menu,
        party: party_state_to_tachyon(sess_state.party),
        invitedToParties: Enum.map(sess_state.invited_to_parties, &party_state_to_tachyon/1),
        friendIds: Enum.map(friends, fn %{userId: uid} -> uid end),
        outgoingFriendRequest: outgoing,
        incomingFriendRequest: incoming,
        ignoreIds: []
      }
    }

    {:event, "user/self", event, state}
  end

  @impl Handler
  def handle_info({:DOWN, _, :process, _, reason}, state) do
    Logger.warning(
      "Session for player went down because #{inspect(reason)}, terminating connection"
    )

    {:stop, :normal,
     {1008, "Server error: session process exited with reason #{inspect(reason)}"}, state}
  end

  def handle_info({:matchmaking, {:notify_found, queue_id, timeout_ms}}, state) do
    resp = %{
      queueId: queue_id,
      timeoutMs: timeout_ms
    }

    {:event, "matchmaking/found", resp, state}
  end

  def handle_info({:matchmaking, {:found_update, ready_count}}, state) do
    resp = %{
      readyCount: ready_count
    }

    {:event, "matchmaking/foundUpdate", resp, state}
  end

  def handle_info({:matchmaking, :notify_lost}, state) do
    {:event, "matchmaking/lost", state}
  end

  def handle_info({:matchmaking, {:cancelled, reason}}, state) do
    data =
      case reason do
        :cancel -> %{reason: :intentional}
        :timeout -> %{reason: :ready_timeout}
        {:server_error, details} -> %{reason: :server_error, details: details}
        err -> %{reason: err}
      end

    {:event, "matchmaking/cancelled", data, state}
  end

  def handle_info({:matchmaking, {:queues_joined, queues}}, state) do
    data = %{queues: queues}
    {:event, "matchmaking/queuesJoined", data, state}
  end

  def handle_info({:battle_start, data}, state) do
    {:request, "battle/start", data, [], state}
  end

  def handle_info({:messaging, {:dm_received, message}}, state) do
    {:event, "messaging/received", message_to_tachyon(message), state}
  end

  def handle_info({:friend, {:request_received, from_id}}, state) do
    {:event, "friend/requestReceived", %{from: to_string(from_id)}, state}
  end

  def handle_info({:friend, {:request_cancelled, from_id}}, state) do
    {:event, "friend/requestCancelled", %{from: to_string(from_id)}, state}
  end

  def handle_info({:friend, {:request_accepted, from_id}}, state) do
    {:event, "friend/requestAccepted", %{from: to_string(from_id)}, state}
  end

  def handle_info({:friend, {:request_rejected, from_id}}, state) do
    {:event, "friend/requestRejected", %{from: to_string(from_id)}, state}
  end

  def handle_info({:friend, {:removed, from_id}}, state) do
    {:event, "friend/removed", %{from: to_string(from_id)}, state}
  end

  def handle_info({:user, {:user_updated, user_state}}, state) do
    event = %{
      users: [
        %{
          userId: to_string(user_state.user_id),
          username: user_state.username,
          clanId: user_state.clan_id,
          country: user_state.country,
          status: user_state.status
        }
      ]
    }

    {:event, "user/updated", event, state}
  end

  def handle_info({:party, {:invited, party_state}}, state) do
    event = %{party: party_state_to_tachyon(party_state)}
    {:event, "party/invited", event, state}
  end

  def handle_info({:party, {:updated, party_state}}, state) do
    event = party_state_to_tachyon(party_state)
    {:event, "party/updated", event, state}
  end

  def handle_info({:party, {:removed, party_id}}, state) do
    event = %{partyId: party_id}
    {:event, "party/removed", event, state}
  end

  def handle_info({:timeout, message_id}, state)
      when is_map_key(state.pending_responses, message_id) do
    Logger.debug("User did not reply in time to request with id #{message_id}")
    {:stop, :normal, state}
  end

  def handle_info(%{}, state) do
    {:ok, state}
  end

  @impl Handler
  @spec handle_command(
          Schema.command_id(),
          Schema.message_type(),
          Schema.message_id(),
          term(),
          state()
        ) :: WebSock.handle_result()
  def handle_command("system/disconnect", "request", _message_id, _message, state) do
    Player.Session.disconnect(state.user.id)

    {:stop, :normal, state}
  end

  def handle_command("system/serverStats", "request", _message_id, _message, state) do
    user_count = Teiserver.Player.SessionRegistry.count()

    {:response, %{userCount: user_count}, state}
  end

  def handle_command("matchmaking/list", "request", _message_id, _message, state) do
    queues =
      Matchmaking.list_queues()
      |> Enum.map(fn {qid, queue} ->
        game_names = Enum.map(queue.games, fn game -> %{springName: game.spring_game} end)
        map_names = Enum.map(queue.maps, fn map -> %{springName: map.spring_name} end)

        %{
          id: qid,
          name: queue.name,
          numOfTeams: queue.team_count,
          teamSize: queue.team_size,
          ranked: queue.ranked,
          engines: queue.engines,
          games: game_names,
          maps: map_names
        }
      end)

    {:response, %{playlists: queues}, state}
  end

  def handle_command("matchmaking/queue", "request", _message_id, message, state) do
    queue_ids = message["data"]["queues"]

    case Player.Session.join_queues(state.user.id, queue_ids) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        case reason do
          :invalid_queue ->
            {:error_response, :invalid_queue_specified, state}

          :too_many_players ->
            {:error_response, :invalid_request, "too many player for a playlist", state}

          :missing_engines ->
            {:error_response, :internal_error, "missing engine list", state}

          :missing_games ->
            {:error_response, :internal_error, "missing game list", state}

          :missing_maps ->
            {:error_response, :internal_error, "missing map list", state}

          :party_too_big ->
            {:error_response, :invalid_request, "party too big", state}

          x ->
            {:error_response, x, state}
        end
    end
  end

  def handle_command("matchmaking/cancel" = cmd_id, "request", message_id, _message, state) do
    case Player.Session.leave_queues(state.user.id) do
      :ok ->
        messages = [
          {:text, Schema.response(cmd_id, message_id) |> Jason.encode!()},
          {:text,
           Schema.event("matchmaking/cancelled", %{reason: :intentional}) |> Jason.encode!()}
        ]

        {:push, messages, state}

      {:error, reason} ->
        {:error_response, reason, state}
    end
  end

  def handle_command("matchmaking/ready", "request", _message_id, _message, state) do
    case Player.Session.matchmaking_ready(state.user.id) do
      :ok -> {:response, state}
      {:error, :no_match} -> {:error_response, :no_match, state}
    end
  end

  def handle_command("messaging/send", "request", _message_id, msg, state) do
    with {:ok, target} <- message_target_from_tachyon(msg["data"]["target"]),
         msg <-
           Messaging.new(
             msg["data"]["message"],
             {:player, state.user.id},
             :erlang.monotonic_time(:micro_seconds)
           ),
         :ok <- Messaging.send(msg, target) do
      {:response, state}
    else
      {:error, :invalid_recipient} ->
        {:error_response, :invalid_target, state}
    end
  end

  def handle_command("messaging/subscribeReceived" = cmd_id, "request", message_id, msg, state) do
    since = parse_since(msg["data"]["since"])

    {:ok, has_missed_messages, msg_to_send} =
      Player.Session.subscribe_received(state.user.id, since)

    response = Schema.response(cmd_id, message_id, %{hasMissedMessages: has_missed_messages})

    msg_to_send =
      Enum.map(msg_to_send, fn msg ->
        Schema.event("messaging/received", message_to_tachyon(msg))
      end)

    messages = [response | msg_to_send] |> Enum.map(fn data -> {:text, Jason.encode!(data)} end)
    {:push, messages, state}
  end

  def handle_command("user/info", "request", _message_id, msg, state) do
    user_id = msg["data"]["userId"]
    user = Account.get_user_by_id(user_id)

    if user != nil do
      resp =
        %{
          userId: to_string(user.id),
          username: user.name,
          displayName: user.name,
          clanId: user.clan_id,
          countryCode: user.country,
          status: :menu
        }

      {:response, resp, state}
    else
      {:error_response, :unknown_user, state}
    end
  end

  def handle_command("friend/list", "request", _message_id, _msg, state) do
    {friends, incoming, outgoing} = get_user_friends(state.user.id)

    resp = %{
      friends: friends,
      incomingPendingRequests: incoming,
      outgoingPendingRequests: outgoing
    }

    {:response, resp, state}
  end

  def handle_command("friend/sendRequest", "request", _message_id, msg, state) do
    with {:ok, target} <- get_user(msg["data"]["to"]),
         {:ok, %Account.FriendRequest{}} <-
           Account.create_friend_request(state.user.id, target.id) do
      Player.Session.friend_request_received(target.id, state.user.id)
      {:response, state}
    else
      {:error, :invalid_user} ->
        {:error_response, :invalid_user, state}

      # this is a bit scuffed and could be refactored so that `create_friend_request`
      # returns an atom instead of a raw string
      {:error, err} when is_binary(err) ->
        {:error_response, :invalid_user, state}

      err ->
        Logger.error("cannot create friend request #{inspect(err)}")
        {:error_response, :internal_error, state}
    end
  end

  def handle_command("friend/acceptRequest", "request", _message_id, msg, state) do
    with {:ok, originator_id} <- parse_user_id(msg["data"]["from"]),
         :ok <- Account.accept_friend_request(originator_id, state.user.id) do
      Player.Session.friend_request_accepted(originator_id, state.user.id)
      {:response, state}
    else
      {:error, :invalid_id} ->
        {:error_response, :invalid_user, state}

      {:error, "no request"} ->
        {:error_response, :no_pending_request, state}
    end
  end

  def handle_command("friend/rejectRequest", "request", _message_id, msg, state) do
    with {:ok, originator_id} <- parse_user_id(msg["data"]["from"]),
         :ok <- Account.decline_friend_request(originator_id, state.user.id) do
      Player.Session.friend_request_rejected(originator_id, state.user.id)
      {:response, state}
    else
      {:error, :invalid_id} ->
        {:error_response, :invalid_user, state}

      {:error, "no request"} ->
        {:error_response, :no_pending_request, state}

      err ->
        Logger.error("Unhandled error in rejectRequest: #{inspect(err)}")

        {:error_response, :internal_error, inspect(err), state}
    end
  end

  def handle_command("friend/cancelRequest", "request", _message_id, msg, state) do
    with {:ok, target_id} <- parse_user_id(msg["data"]["to"]),
         :ok <- Account.rescind_friend_request(state.user.id, target_id) do
      Player.Session.friend_request_cancelled(target_id, state.user.id)
      {:response, state}
    else
      {:error, "no request"} ->
        {:response, state}

      _ ->
        {:error_response, :invalid_user, state}
    end
  end

  def handle_command("friend/remove", "request", _message_id, msg, state) do
    with {:ok, target_id} <- parse_user_id(msg["data"]["userId"]),
         %Account.Friend{} = friend <- Account.get_friend(state.user.id, target_id),
         {:ok, _changeset} <- Account.delete_friend(friend) do
      Player.Session.friend_removed(target_id, state.user.id)
      {:response, state}
    else
      nil ->
        {:response, state}

      {:error, :invalid_id} ->
        {:error_response, :invalid_user, state}

      err ->
        Logger.error("can't remove friend #{inspect(err)}")
        {:error_response, :internal_error, inspect(err), state}
    end
  end

  def handle_command("user/subscribeUpdates", "request", _message_id, msg, state) do
    {ok_ids, invalid_ids} = parse_user_ids(msg["data"]["userIds"])

    if not Enum.empty?(invalid_ids) do
      details = "invalid user ids: #{Enum.join(invalid_ids, ", ")}"
      {:error_response, :invalid_request, details, state}
    else
      case Player.Session.subscribe_updates(state.user.id, ok_ids) do
        :ok ->
          {:response, state}

        {:error, {:invalid_ids, invalid_ids}} ->
          details = "invalid user ids: #{Enum.join(invalid_ids, ", ")}"
          {:error_response, :invalid_request, details, state}
      end
    end
  end

  def handle_command("user/unsubscribeUpdates", "request", _message_id, msg, state) do
    {ok_ids, invalid_ids} = parse_user_ids(msg["data"]["userIds"])

    if not Enum.empty?(invalid_ids) do
      details = "invalid user ids: #{Enum.join(invalid_ids, ", ")}"
      {:error_response, :invalid_request, details, state}
    else
      case Player.Session.unsubscribe_updates(state.user.id, ok_ids) do
        :ok ->
          {:response, state}

        {:error, {:invalid_ids, invalid_ids}} ->
          details = "invalid user ids: #{Enum.join(invalid_ids, ", ")}"
          {:error_response, :invalid_request, details, state}
      end
    end
  end

  def handle_command("party/create", "request", _message_id, _msg, state) do
    case Player.Session.create_party(state.user.id) do
      {:ok, party_id} ->
        data = %{partyId: party_id}
        {:response, data, state}

      {:error, :already_in_party} ->
        {:error_response, :invalid_request, "Already in a party", state}

      {:error, reason} ->
        {:error_response, :internal_error, to_string(reason), state}
    end
  end

  def handle_command("party/leave", "request", _message_id, _msg, state) do
    case Player.Session.leave_party(state.user.id) do
      :ok -> {:response, state}
      {:error, :not_in_party} -> {:error_response, :invalid_request, "Not in a party", state}
      {:error, reason} -> {:error_response, :internal_error, to_string(reason), state}
    end
  end

  def handle_command("party/invite", "request", _message_id, msg, state) do
    raw_user_id = msg["data"]["userId"]

    with {:ok, id} <- parse_user_id(raw_user_id),
         :ok <- Player.Session.invite_to_party(state.user.id, id) do
      {:response, state}
    else
      {:error, reason} when reason in [:invalid_player, :invalid_user] ->
        {:error_response, :invalid_request,
         "User with id #{raw_user_id} isn't valid or connected"}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("party/acceptInvite", "request", _message_id, msg, state) do
    party_id = msg["data"]["partyId"]

    case Player.Session.accept_invite_to_party(state.user.id, party_id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("party/declineInvite", "request", _message_id, msg, state) do
    party_id = msg["data"]["partyId"]

    case Player.Session.decline_invite_to_party(state.user.id, party_id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("party/cancelInvite", "request", _message_id, msg, state) do
    with {:ok, user_id} <- parse_user_id(msg["data"]["userId"]),
         :ok <- Player.Session.cancel_invite_to_party(state.user.id, user_id) do
      {:response, state}
    else
      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("party/kickMember", "request", _message_id, msg, state) do
    with {:ok, target_id} <- parse_user_id(msg["data"]["userId"]),
         :ok <- Player.Session.kick_party_member(state.user.id, target_id) do
      {:response, state}
    else
      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command(_command_id, _message_type, _message_id, _message, state) do
    {:error_response, :command_unimplemented, state}
  end

  # Ensure a session is started for the given user id. Register both the session
  # and the connection. If a connection already exists, terminates it and
  # replace it in the player registry.
  # More work is required here, to seed the session with some initial
  # state. Because if the node holding the session process shuts down,
  # restarting the connection (through the supervisor) isn't enough.
  # The state associated with the connected player will not match
  # the brand new session.
  defp setup_session(user) do
    case Player.SessionSupervisor.start_session(user) do
      {:ok, session_pid} ->
        {:ok, _} = Player.Registry.register_and_kill_existing(user.id)
        {:ok, session_pid, %{party: nil, invited_to_parties: []}}

      {:error, {:already_started, pid}} ->
        case Player.Session.replace_connection(pid, self()) do
          # This can happen when the session dies/terminate between the
          # start_session and the replace_connection. In which case, try again.
          # When a user disconnect and immediately reconnect it can happen
          # that the session is still registered
          :died ->
            setup_session(user)

          {:ok, sess_state} ->
            {:ok, _} = Player.Registry.register_and_kill_existing(user.id)
            {:ok, pid, sess_state}
        end
    end
  end

  defp message_source_to_tachyon(source) do
    case source do
      {:player, player_id} -> %{type: "player", userId: to_string(player_id)}
    end
  end

  defp message_target_from_tachyon(target) do
    case target["type"] do
      "player" ->
        case Integer.parse(target["userId"]) do
          {user_id, ""} -> {:ok, {:player, user_id}}
          _ -> {:error, :invalid_recipient}
        end

      _ ->
        {:error, :invalid_recipient}
    end
  end

  defp message_to_tachyon(message) do
    %{
      message: message.content,
      source: message_source_to_tachyon(message.source),
      timestamp: message.timestamp,
      marker: to_string(message.marker)
    }
  end

  defp parse_since(nil), do: :latest
  defp parse_since(%{"type" => "latest"}), do: :latest
  defp parse_since(%{"type" => "from_start"}), do: :from_start

  defp parse_since(%{"type" => "marker", "value" => marker}) do
    case Integer.parse(marker) do
      {m, ""} -> {:marker, m}
      # invalid markers won't be found in the queue
      _ -> {:marker, :invalid}
    end
  end

  # that kind of parsing can probably be extracted, will likely be generally useful
  @spec parse_user_ids([String.t()]) :: {[T.userid()], [String.t()]}
  defp parse_user_ids(raw_ids) do
    Enum.reduce(raw_ids, {[], []}, fn raw_id, {ok, invalid} ->
      case Integer.parse(raw_id) do
        {id, ""} -> {[id | ok], invalid}
        _ -> {ok, [raw_id | invalid]}
      end
    end)
  end

  defp parse_user_id(raw) do
    case Integer.parse(raw) do
      {id, ""} -> {:ok, id}
      _ -> {:error, :invalid_id}
    end
  end

  @spec get_user(String.t()) :: {:ok, T.user()} | {:error, :invalid_user}
  defp get_user(raw_id) do
    with {:ok, user_id} <- parse_user_id(raw_id),
         user when not is_nil(user) <- Account.get_user(user_id) do
      {:ok, user}
    else
      _ -> {:error, :invalid_user}
    end
  end

  @spec get_user_friends(T.userid()) ::
          {friends :: [term()], incoming :: [term()], outgoing :: [term()]}
  def get_user_friends(user_id) do
    epoch = ~N[1970-01-01 00:00:00]

    friends =
      Account.list_friends_for_user(user_id)
      |> Enum.map(fn friend ->
        id = if friend.user1_id == user_id, do: friend.user2_id, else: friend.user1_id
        %{userId: to_string(id), addedAt: NaiveDateTime.diff(friend.inserted_at, epoch)}
      end)

    {outgoing, incoming} = Account.list_requests_for_user(user_id)

    incoming =
      Enum.map(incoming, fn req ->
        %{from: to_string(req.from_user_id), sentAt: NaiveDateTime.diff(req.inserted_at, epoch)}
      end)

    outgoing =
      Enum.map(outgoing, fn req ->
        %{to: to_string(req.to_user_id), sentAt: NaiveDateTime.diff(req.inserted_at, epoch)}
      end)

    {friends, incoming, outgoing}
  end

  defp party_state_to_tachyon(nil), do: nil

  defp party_state_to_tachyon(party_state) do
    %{
      id: party_state.id,
      members:
        Enum.map(party_state.members, fn m ->
          %{
            userId: to_string(m.id),
            joinedAt: DateTime.to_unix(m.joined_at, :microsecond)
          }
        end),
      invited:
        Enum.map(party_state.invited, fn m ->
          %{
            userId: to_string(m.id),
            invitedAt: DateTime.to_unix(m.invited_at)
          }
        end)
    }
  end
end
