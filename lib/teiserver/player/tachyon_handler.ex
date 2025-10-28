defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  require Logger
  alias Teiserver.Helpers.BurstyRateLimiter
  alias Teiserver.Tachyon.Schema
  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T
  alias Teiserver.{Account, Player, Matchmaking, Messaging}
  alias Teiserver.Helpers.TachyonParser

  @behaviour Handler

  @type state :: %{
          user: T.user(),
          sess_monitor: reference(),
          pending_responses: Handler.pending_responses()
        }

  @impl Handler
  def connect(conn) do
    lobby_client = conn.assigns[:token].application.uid
    user = conn.assigns[:token].owner

    with addr when is_list(addr) <- :inet.ntoa(conn.remote_ip),
         {:ok, user} <- Teiserver.CacheUser.tachyon_login(user, to_string(addr), lobby_client) do
      {:ok, %{user: user}}
    else
      {:error, :einval} ->
        {:error, 404, "Invalid remote address"}

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

    event = build_user_self_event(user, sess_state)
    {:event, "user/self", event, state}
  end

  @impl Handler
  def init_rate_limiter(_state) do
    BurstyRateLimiter.per_second(10) |> BurstyRateLimiter.with_burst(20)
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

  def handle_info({:messaging, {:received, message}}, state) do
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
          status: user_state.status,
          roles: roles_to_tachyon(user_state.roles)
        }
      ]
    }

    {:event, "user/updated", event, state}
  end

  def handle_info({:user, {:role_updated, roles}}, state) do
    event = build_user_self_event(%{state.user | roles: roles}, state)
    {:event, "user/self", event, state}
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

  def handle_info({:lobby, lobby_id, {:updated, update}}, state) do
    data = lobby_update_to_tachyon(lobby_id, update)

    {:event, "lobby/updated", data, state}
  end

  def handle_info({:lobby, lobby_id, {:left, reason}}, state) do
    {:event, "lobby/left", %{id: lobby_id, reason: reason}, state}
  end

  def handle_info({:lobby_list, {:add_lobby, lobby_id, overview}}, state) do
    data = %{lobbies: %{lobby_id => lobby_overview_to_tachyon(lobby_id, overview)}}
    {:event, "lobby/listUpdated", data, state}
  end

  def handle_info({:lobby_list, {:update_lobby, lobby_id, overview}}, state) do
    data = %{lobbies: %{lobby_id => lobby_overview_to_tachyon(lobby_id, overview)}}
    {:event, "lobby/listUpdated", data, state}
  end

  def handle_info({:lobby_list, {:remove_lobby, lobby_id}}, state) do
    data = %{lobbies: %{lobby_id => nil}}
    {:event, "lobby/listUpdated", data, state}
  end

  def handle_info({:lobby_list, {:reset_list, lobbies}}, state) do
    lobbies =
      Enum.map(lobbies, fn {lobby_id, overview} ->
        {lobby_id, lobby_overview_to_tachyon(lobby_id, overview)}
      end)
      |> Enum.into(%{})

    {:event, "lobby/listReset", %{lobbies: lobbies}, state}
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

  def handle_command("matchmaking/cancel", "request", _message_id, _message, state) do
    case Player.Session.leave_queues(state.user.id) do
      :ok ->
        {:response, {nil, [Schema.event("matchmaking/cancelled", %{reason: :intentional})]},
         state}

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
    with {:ok, target} <- message_target_from_tachyon(msg["data"]["target"]) do
      case target do
        {:player, _} ->
          msg =
            Messaging.new(
              msg["data"]["message"],
              {:player, state.user.id},
              :erlang.monotonic_time(:micro_seconds)
            )

          case Messaging.send(msg, target) do
            :ok -> {:response, state}
            {:error, :invalid_recipient} -> {:error_response, :invalid_target, state}
          end

        :party ->
          case Player.Session.send_party_message(state.user.id, msg["data"]["message"]) do
            :ok -> {:response, state}
            {:error, reason} -> {:error_response, :invalid_request, inspect(reason), state}
          end
      end
    else
      {:error, :invalid_recipient} ->
        {:error_response, :invalid_target, state}
    end
  end

  def handle_command("messaging/subscribeReceived", "request", _message_id, msg, state) do
    since = parse_since(msg["data"]["since"])

    {:ok, has_missed_messages, msg_to_send} =
      Player.Session.subscribe_received(state.user.id, since)

    response = %{hasMissedMessages: has_missed_messages}

    msg_to_send =
      Enum.map(msg_to_send, fn msg ->
        Schema.event("messaging/received", message_to_tachyon(msg))
      end)

    {:response, {response, msg_to_send}, state}
  end

  def handle_command("user/info", "request", _message_id, msg, state) do
    user_id = msg["data"]["userId"]
    user = Account.get_user_by_id(user_id)

    if user != nil do
      %{status: status} = Player.Session.get_user_info(user.id)

      resp =
        %{
          userId: to_string(user.id),
          username: user.name,
          displayName: user.name,
          clanId: user.clan_id,
          countryCode: user.country,
          status: status,
          roles: roles_to_tachyon(user.roles)
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
         {:ok, data} <- Account.create_friend_request(state.user.id, target.id) do
      case data do
        %Account.FriendRequest{} ->
          Player.Session.friend_request_received(target.id, state.user.id)

        :auto_accepted ->
          Player.Session.friend_request_accepted(target.id, state.user.id)
          Player.Session.friend_request_accepted(state.user.id, target.id)
      end

      {:response, state}
    else
      {:error, :invalid_user} ->
        {:error_response, :invalid_user, state}

      {:error, :already_in_friendlist} ->
        {:error_response, :already_in_friendlist, state}

      {:error, :outgoing_capacity_reached} ->
        {:error_response, :outgoing_capacity_reached, state}

      {:error, :incoming_capacity_reached} ->
        {:error_response, :incoming_capacity_reached, state}

      err ->
        Logger.error("cannot create friend request #{inspect(err)}")
        {:error_response, :internal_error, state}
    end
  end

  def handle_command("friend/acceptRequest", "request", _message_id, msg, state) do
    with {:ok, originator_id} <- TachyonParser.parse_user_id(msg["data"]["from"]),
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
    with {:ok, originator_id} <- TachyonParser.parse_user_id(msg["data"]["from"]),
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
    with {:ok, target_id} <- TachyonParser.parse_user_id(msg["data"]["to"]),
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
    with {:ok, target_id} <- TachyonParser.parse_user_id(msg["data"]["userId"]),
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
    {ok_ids, invalid_ids} = TachyonParser.parse_user_ids(msg["data"]["userIds"])

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
    {ok_ids, invalid_ids} = TachyonParser.parse_user_ids(msg["data"]["userIds"])

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
        {:error_response, :internal_error, inspect(reason), state}
    end
  end

  def handle_command("party/leave", "request", _message_id, _msg, state) do
    case Player.Session.leave_party(state.user.id) do
      :ok ->
        {:response, state}

      {:error, :not_in_party} ->
        {:error_response, :invalid_request, "Not in a party", state}

      {:error, :invalid_party} ->
        {:error_response, :invalid_request, "Invalid party", state}

      {:error, reason} ->
        {:error_response, :internal_error, inspect(reason), state}
    end
  end

  def handle_command("party/invite", "request", _message_id, msg, state) do
    raw_user_id = msg["data"]["userId"]

    with {:ok, id} <- TachyonParser.parse_user_id(raw_user_id),
         :ok <- Player.Session.invite_to_party(state.user.id, id) do
      {:response, state}
    else
      {:error, reason} when reason in [:invalid_player, :invalid_user] ->
        {:error_response, :invalid_request,
         "User with id #{raw_user_id} isn't valid or connected", state}

      {:error, reason} ->
        {:error_response, :invalid_request, inspect(reason), state}
    end
  end

  def handle_command("party/acceptInvite", "request", _message_id, msg, state) do
    party_id = msg["data"]["partyId"]

    case Player.Session.accept_invite_to_party(state.user.id, party_id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, inspect(reason), state}
    end
  end

  def handle_command("party/declineInvite", "request", _message_id, msg, state) do
    party_id = msg["data"]["partyId"]

    case Player.Session.decline_invite_to_party(state.user.id, party_id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, inspect(reason), state}
    end
  end

  def handle_command("party/cancelInvite", "request", _message_id, msg, state) do
    with {:ok, user_id} <- TachyonParser.parse_user_id(msg["data"]["userId"]),
         :ok <- Player.Session.cancel_invite_to_party(state.user.id, user_id) do
      {:response, state}
    else
      {:error, reason} ->
        {:error_response, :invalid_request, inspect(reason), state}
    end
  end

  def handle_command("party/kickMember", "request", _message_id, msg, state) do
    with {:ok, target_id} <- TachyonParser.parse_user_id(msg["data"]["userId"]),
         :ok <- Player.Session.kick_party_member(state.user.id, target_id) do
      {:response, state}
    else
      {:error, reason} ->
        {:error_response, :invalid_request, inspect(reason), state}
    end
  end

  def handle_command("lobby/create", "request", _msg_id, msg, state) do
    # TODO: the `lobby/update` has very similar logic. There should be a way
    # to combine the parsing
    create_data = %{
      name: msg["data"]["name"],
      map_name: msg["data"]["mapName"],
      ally_team_config:
        for at <- msg["data"]["allyTeamConfig"] do
          sb = at["startBox"]
          teams = for t <- at["teams"], do: %{max_players: t["maxPlayers"]}

          %{
            max_teams: at["maxTeams"],
            start_box: %{
              top: sb["top"],
              bottom: sb["bottom"],
              left: sb["left"],
              right: sb["right"]
            },
            teams: teams
          }
        end
    }

    case Player.Session.create_lobby(state.user.id, create_data) do
      {:ok, details} ->
        data = lobby_details_to_tachyon(details)

        {:response, data, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/join", "request", _msg_id, msg, state) do
    case Player.Session.lobby_join(state.user.id, msg["data"]["id"]) do
      {:ok, details} ->
        data = lobby_details_to_tachyon(details)
        {:response, data, state}

      {:error, :lobby_full} ->
        {:error_response, :lobby_full, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/leave", "request", _msg_id, _msg, state) do
    case Player.Session.lobby_leave(state.user.id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/joinAllyTeam", "request", _msg_id, msg, state) do
    with {:ok, ally_team} <- TachyonParser.parse_int(msg["data"]["allyTeam"]),
         :ok <- Player.Session.lobby_join_ally_team(state.user.id, ally_team) do
      {:response, state}
    else
      {:error, :invalid_int} ->
        {:error_response, :invalid_request, "Invalid ally team", state}

      {:error, reason} when reason in [:not_in_lobby, :ally_team_full] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/spectate", "request", _msg_id, _msg, state) do
    case Player.Session.lobby_spectate(state.user.id) do
      :ok ->
        {:response, state}

      {:error, reason} when reason in [:not_in_lobby] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/joinQueue", "request", _msg_id, _msg, state) do
    case Player.Session.lobby_join_queue(state.user.id) do
      :ok ->
        {:response, state}

      {:error, reason} when reason in [:not_in_lobby] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/addBot", "request", _msg_id, %{"data" => data}, state) do
    opts =
      [{:name, data["name"]}, {:version, data["version"]}, {:options, data["options"]}]
      |> Enum.filter(&(elem(&1, 1) != nil))

    with {:ok, ally_team} <- TachyonParser.parse_int(data["allyTeam"]),
         {:ok, bot_id} <-
           Player.Session.lobby_add_bot(state.user.id, ally_team, data["shortName"], opts) do
      {:response, %{id: bot_id}, state}
    else
      {:error, :invalid_int} ->
        {:error_response, :invalid_request, "Invalid ally team", state}

      {:error, reason} when reason in [:not_in_lobby, :ally_team_full] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/removeBot", "request", _msg_id, msg, state) do
    case Player.Session.lobby_remove_bot(state.user.id, msg["data"]["id"]) do
      :ok ->
        {:response, state}

      {:error, reason} when reason in [:not_in_lobby, :invalid_bot] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/updateBot", "request", _msg_id, %{"data" => data}, state) do
    keys = [
      {"name", :name},
      {"shortName", :short_name},
      {"version", :version},
      {"options", :options}
    ]

    update_data =
      Enum.reduce(keys, %{id: data["id"]}, fn {tk, k}, m ->
        if is_map_key(data, tk) do
          Map.put(m, k, Map.get(data, tk))
        else
          m
        end
      end)

    case Player.Session.lobby_update_bot(state.user.id, update_data) do
      :ok ->
        {:response, state}

      {:error, reason} when reason in [:not_in_lobby, :invalid_bot] ->
        {:error_response, reason, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/update", "request", _msg_id, %{"data" => data}, state) do
    keys = [
      {"name", :name},
      {"mapName", :map_name},
      {"allyTeamConfig", :ally_team_config, &ally_team_config_from_tachyon/1}
    ]

    update_data = Enum.reduce(keys, %{}, &convert_key(&1, data, &2))

    case Player.Session.lobby_update_properties(state.user.id, update_data) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/startBattle", "request", _msg_id, _msg, state) do
    case Player.Session.lobby_start_battle(state.user.id) do
      :ok ->
        {:response, state}

      {:error, reason} ->
        {:error_response, :invalid_request, to_string(reason), state}
    end
  end

  def handle_command("lobby/subscribeList", "request", _msg_id, _msg, state) do
    case Player.Session.subscribe_lobby_list(state.user.id) do
      {:ok, list} ->
        ev =
          Schema.event("lobby/listReset", %{
            lobbies:
              Enum.map(list, fn {id, overview} ->
                {id, lobby_overview_to_tachyon(id, overview)}
              end)
              |> Enum.into(%{})
          })

        {:response, {nil, [ev]}, state}
    end
  end

  def handle_command("lobby/unsubscribeList", "request", _msg_id, _msg, state) do
    :ok = Player.Session.unsubscribe_lobby_list(state.user.id)
    {:response, state}
  end

  def handle_command(_command_id, _message_type, _message_id, _message, state) do
    {:error_response, :command_unimplemented, state}
  end

  defp build_user_self_event(user, sess_state) do
    {friends, incoming, outgoing} = get_user_friends(user.id)

    %{
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
        ignoreIds: [],
        currentLobby: nil,
        roles: roles_to_tachyon(user.roles)
      }
    }
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
      {:player, player_id} ->
        %{type: :player, userId: to_string(player_id)}

      {:party, party_id, sender_id} ->
        %{type: :party, partyId: party_id, userId: to_string(sender_id)}
    end
  end

  defp message_target_from_tachyon(target) do
    case target["type"] do
      "player" ->
        case Integer.parse(target["userId"]) do
          {user_id, ""} -> {:ok, {:player, user_id}}
          _ -> {:error, :invalid_recipient}
        end

      "party" ->
        {:ok, :party}

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

  @spec get_user(String.t()) :: {:ok, T.user()} | {:error, :invalid_user}
  defp get_user(raw_id) do
    with {:ok, user_id} <- TachyonParser.parse_user_id(raw_id),
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

  # Converts Teiserver role names to Tachyon role names.
  # Only roles that have Tachyon equivalents are included.
  defp roles_to_tachyon(teiserver_roles) when is_list(teiserver_roles) do
    teiserver_roles
    |> Enum.map(fn role ->
      case role do
        "Contributor" -> "contributor"
        "Admin" -> "admin"
        "Moderator" -> "moderator"
        "Caster" -> "tournament_caster"
        "Tournament winner" -> "tournament_winner"
        _ -> nil
      end
    end)
    |> Enum.reject(&is_nil/1)
  end

  defp ally_team_config_from_tachyon(data) do
    keys = [
      {"maxTeams", :max_teams},
      {"startBox", :start_box, &start_box_from_tachyon/1},
      {"teams", :teams, &teams_from_tachyon/1}
    ]

    Enum.map(data, fn d -> Enum.reduce(keys, %{}, &convert_key(&1, d, &2)) end)
  end

  defp start_box_from_tachyon(data) do
    keys = [{"top", :top}, {"bottom", :bottom}, {"left", :left}, {"right", :right}]
    Enum.reduce(keys, %{}, &convert_key(&1, data, &2))
  end

  # util function to convert keys in a map, with a possible transformation for the val
  defp convert_key(key_spec, data, map) do
    case key_spec do
      {from_k, to_k} ->
        if is_map_key(data, from_k) do
          Map.put(map, to_k, Map.get(data, from_k))
        else
          map
        end

      {from_k, to_k, f} ->
        if is_map_key(data, from_k) do
          Map.put(map, to_k, f.(Map.get(data, from_k)))
        else
          map
        end
    end
  end

  defp teams_from_tachyon(data) do
    Enum.map(data, fn d -> %{max_players: d["maxPlayers"]} end)
  end

  defp lobby_team_to_tachyon({x, y, z}) do
    %{
      allyTeam: x |> to_string(),
      team: y |> to_string(),
      player: z |> to_string()
    }
  end

  defp lobby_details_to_tachyon(details) do
    players =
      Enum.map(details.players, fn {p_id, p} ->
        {to_string(p_id), player_update_to_tachyon(to_string(p_id), p, true)}
      end)
      |> Map.new()

    spectators =
      Enum.map(details.spectators, fn {s_id, s} ->
        {to_string(s_id), spectator_update_to_tachyon(to_string(s_id), s, true)}
      end)
      |> Map.new()

    bots =
      Enum.map(details.bots, fn {b_id, b} ->
        {b_id, bot_update_to_tachyon(b_id, b, true)}
      end)
      |> Map.new()

    ally_team_config =
      for {at, at_idx} <- Enum.with_index(details.ally_team_config), into: %{} do
        teams =
          for {t, t_idx} <- Enum.with_index(at.teams), into: %{} do
            {to_string(t_idx), %{maxPlayers: t.max_players}}
          end

        {to_string(at_idx),
         %{
           teams: teams,
           maxTeams: at.max_teams,
           startBox: at.start_box
         }}
      end

    %{
      id: details.id,
      name: details.name,
      players: players,
      spectators: spectators,
      bots: bots,
      mapName: details.map_name,
      engineVersion: details.engine_version,
      gameVersion: details.game_version,
      allyTeamConfig: ally_team_config
    }
    |> then(fn m ->
      case details.current_battle do
        nil ->
          m

        b ->
          Map.put(m, :currentBattle, %{startedAt: DateTime.to_unix(b.started_at, :microsecond)})
      end
    end)
  end

  defp lobby_update_to_tachyon(lobby_id, update_map) do
    data =
      %{id: lobby_id}
      |> then(fn m ->
        case Map.get(update_map, :players) do
          nil ->
            m

          players ->
            players =
              Enum.map(players, fn {p_id, updates} ->
                {to_string(p_id), player_update_to_tachyon(to_string(p_id), updates, false)}
              end)
              |> Map.new()

            Map.put(m, :players, players)
        end
      end)
      |> then(fn m ->
        case Map.get(update_map, :spectators) do
          nil ->
            m

          spectators ->
            specs =
              Enum.map(spectators, fn {s_id, updates} ->
                {to_string(s_id), spectator_update_to_tachyon(to_string(s_id), updates, false)}
              end)
              |> Map.new()

            Map.put(m, :spectators, specs)
        end
      end)
      |> then(fn m ->
        if is_map_key(update_map, :current_battle) do
          battle = update_map.current_battle

          if battle == nil do
            Map.put(m, :currentBattle, nil)
          else
            Map.put(m, :currentBattle, %{
              id: battle.id,
              startedAt: DateTime.to_unix(battle.started_at, :microsecond)
            })
          end
        else
          m
        end
      end)
      |> then(fn m ->
        case Map.get(update_map, :bots) do
          nil ->
            m

          bots ->
            bots =
              Enum.map(bots, fn {b_id, updates} ->
                {b_id, bot_update_to_tachyon(b_id, updates, false)}
              end)
              |> Map.new()

            Map.put(m, :bots, bots)
        end
      end)
      |> then(fn m ->
        case Map.get(update_map, :name) do
          nil -> m
          v -> Map.put(m, :name, v)
        end
      end)
      |> then(fn m ->
        case Map.get(update_map, :map_name) do
          nil -> m
          v -> Map.put(m, :mapName, v)
        end
      end)
      |> then(fn m ->
        case Map.get(update_map, :ally_team_config) do
          nil ->
            m

          v ->
            val =
              for {at, i} <- Enum.with_index(v), into: %{} do
                {to_string(i),
                 %{
                   maxTeams: at.max_teams,
                   # internal representation is the same as tachyon for startbox
                   startBox: at.start_box,
                   teams:
                     for {team, i} <- Enum.with_index(at.teams), into: %{} do
                       {to_string(i), %{maxPlayers: team.max_players}}
                     end
                 }}
              end

            Map.put(m, :allyTeamConfig, val)
        end
      end)

    # TODO: this is getting out of control, figure out a way to serialize these things.

    data
  end

  # omit_nil? is there so we can use the same function for both the initial
  # object and any subsequent json patch style updates
  # because the initial object cannot have nil keys, so just skip them if any
  defp player_update_to_tachyon(_p_id, nil, _omit_nil?), do: nil

  defp player_update_to_tachyon(p_id, updates, omit_nil?) do
    if is_map_key(updates, :team) do
      val = updates.team

      cond do
        val == nil && omit_nil? -> %{}
        val == nil -> %{allyTeam: nil, team: nil, player: nil}
        true -> lobby_team_to_tachyon(val)
      end
    else
      %{}
    end
    |> Map.put(:id, p_id)
  end

  defp spectator_update_to_tachyon(_p_id, nil, _omit_nil?), do: nil

  defp spectator_update_to_tachyon(p_id, updates, omit_nil?) do
    base = %{id: p_id}
    key_mapping = [{:join_queue_position, :joinQueuePosition}]
    to_json_merge_patch(base, updates, key_mapping, omit_nil?)
  end

  defp bot_update_to_tachyon(_b_id, nil, _omit_nil?), do: nil

  defp bot_update_to_tachyon(b_id, updates, omit_nil?) do
    base =
      if is_map_key(updates, :team) do
        val = updates.team

        cond do
          val == nil && omit_nil? -> %{}
          val == nil -> %{allyTeam: nil, team: nil, player: nil}
          true -> lobby_team_to_tachyon(val)
        end
      else
        %{}
      end
      |> Map.put(:id, b_id)

    key_mapping = [
      {:host_user_id, :hostUserId, &to_string/1},
      {:short_name, :shortName},
      {:name, :name},
      {:version, :version},
      {:options, :options}
    ]

    to_json_merge_patch(base, updates, key_mapping, omit_nil?)
  end

  # handle partial overview object
  defp lobby_overview_to_tachyon(lobby_id, overview) do
    key_mapping = [
      {:name, :name},
      {:player_count, :playerCount},
      {:max_player_count, :maxPlayerCount},
      {:map_name, :mapName},
      {:engine_version, :engineVersion},
      {:game_version, :gameVersion},
      {:current_battle, :currentBattle, &lobby_current_battle_to_tachyon/1}
    ]

    base = %{id: lobby_id, currentBattle: nil}
    to_json_merge_patch(base, overview, key_mapping, true)
  end

  defp lobby_current_battle_to_tachyon(battle) do
    %{startedAt: DateTime.to_unix(battle.started_at, :microsecond)}
  end

  defp to_json_merge_patch(initial_map, map_to_transform, key_mapping, omit_nil?) do
    Enum.reduce(key_mapping, initial_map, fn
      {k, tachyon_k}, m ->
        if is_map_key(map_to_transform, k) do
          val = Map.get(map_to_transform, k)

          cond do
            val == nil && omit_nil? -> m
            val == nil -> Map.put(m, tachyon_k, nil)
            true -> Map.put(m, tachyon_k, val)
          end
        else
          m
        end

      {k, tachyon_k, f}, m ->
        if is_map_key(map_to_transform, k) do
          val = Map.get(map_to_transform, k)

          cond do
            val == nil && omit_nil? -> m
            val == nil -> Map.put(m, tachyon_k, nil)
            true -> Map.put(m, tachyon_k, f.(val))
          end
        else
          m
        end
    end)
  end
end
