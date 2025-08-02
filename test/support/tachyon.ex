defmodule Teiserver.Support.Tachyon do
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.OAuthFixtures

  def tachyon_case_setup(tags) do
    if String.contains?(to_string(tags[:module]), "Tachyon") || tags[:tachyon] do
      :ok = Supervisor.terminate_child(Teiserver.Supervisor, Teiserver.Tachyon.System)
      {:ok, _pid} = Supervisor.restart_child(Teiserver.Supervisor, Teiserver.Tachyon.System)
    end
  end

  def create_user() do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    set_ratings(user, 17)
    user
  end

  @spec set_rating(Teiserver.Account.User.t(), rating_type :: String.t(), number() | map()) ::
          Teiserver.Account.Rating.t()
  def set_rating(user, rating_type, r) do
    rating = Teiserver.Game.get_rating_type_by_name!(rating_type)
    [r] = set_ratings(user, [{rating, r}])
    r
  end

  @spec set_ratings(
          Teiserver.Account.User.t(),
          rating :: number() | [{Teiserver.Game.RatingType.t(), number() | map()}]
        ) :: [Teiserver.Account.Rating.t()]
  @doc """
  Set rating for all game type for this user
  """
  def set_ratings(user, r) when is_number(r) do
    ratings =
      Teiserver.Game.list_rating_types()
      |> Enum.map(fn rating -> {rating, r} end)

    set_ratings(user, ratings)
  end

  def set_ratings(user, ratings) when is_list(ratings) do
    for {rating_type, attrs} <- ratings do
      attrs =
        if is_number(attrs),
          do: %{skill: attrs},
          else: attrs

      attrs =
        Map.merge(
          %{
            user_id: user.id,
            rating_type_id: rating_type.id,
            rating_value: attrs.skill,
            uncertainty: 1.0,
            leaderboard_rating: 10,
            last_updated: DateTime.utc_now(),
            season: Teiserver.Game.MatchRatingLib.active_season()
          },
          attrs
        )

      {:ok, r} = Teiserver.Account.create_or_update_rating(attrs)
      r
    end
  end

  def setup_client(_context), do: setup_client()

  def setup_client() do
    user = create_user()
    %{client: client, token: token} = connect(user)
    {:ok, user: user, client: client, token: token}
  end

  def setup_autohost(context) do
    autohost = Teiserver.BotFixtures.create_bot()

    token =
      OAuthFixtures.token_attrs(nil, context.app)
      |> Map.drop([:owner_id])
      |> Map.put(:bot_id, autohost.id)
      |> OAuthFixtures.create_token()

    client = connect_autohost!(token, 10, 0)
    ExUnit.Callbacks.on_exit(fn -> cleanup_connection(client, token) end)
    {:ok, autohost: autohost, autohost_client: client}
  end

  @doc """
  connects the given user and returns the ws client
  """
  def connect(x, opts \\ [swallow_first_event: true])

  def connect(%Teiserver.OAuth.Token{} = token, opts) do
    connect_opts =
      connect_options(token)
      |> Keyword.put_new(:default_timeout, 300)

    {:ok, client} = WSC.connect(tachyon_url(), connect_opts)

    # by default, swallow the user/updated event sent at login
    swallow = Keyword.get(opts, :swallow_first_event, true)

    if swallow and not is_nil(token.owner_id) do
      {:ok, _user_updated} = recv_message(client)
    end

    ExUnit.Callbacks.on_exit(fn -> cleanup_connection(client, token) end)
    client
  end

  def connect(user, opts) do
    %{token: token} = OAuthFixtures.setup_token(user)

    client = connect(token, opts)
    %{client: client, token: token}
  end

  # used for on_exit callback and make sure nothing is lingering after the test
  def cleanup_connection(client, _token) do
    WSC.disconnect(client)
  end

  @doc """
  Connect as an autohost and ensure the first `status` event is sent
  """
  def connect_autohost!(token, max_battles, current) do
    client = connect(token)

    :ok =
      send_event(client, "autohost/status", %{
        maxBattles: max_battles,
        currentBattles: current
      })

    %{"type" => "request", "commandId" => "autohost/subscribeUpdates"} =
      request = recv_message!(client)

    :ok = send_response(client, request, data: %{})

    client
  end

  def connect_options(token) do
    [
      connection_options: [
        extra_headers: [
          {"authorization", "Bearer #{token.value}"},
          {"sec-websocket-protocol", "v0.tachyon"}
        ]
      ]
    ]
  end

  def tachyon_url() do
    conf = Application.get_env(:teiserver, TeiserverWeb.Endpoint)
    "ws://#{conf[:url][:host]}:#{conf[:http][:port]}/tachyon"
  end

  # TODO tachyon_mvp: add a json validation here to make sure the request
  # sent there is conforming
  def request(command_id, data \\ nil) do
    req = %{
      type: :request,
      commandId: command_id,
      messageId: UUID.uuid4()
    }

    if is_nil(data) do
      req
    else
      Map.put(req, :data, data)
    end
  end

  def response(request, opts) do
    resp = %{
      type: :response,
      commandId: request["commandId"],
      messageId: request["messageId"]
    }

    cond do
      not is_nil(opts[:data]) ->
        resp
        |> Map.put(:status, :success)
        |> Map.put(:data, opts[:data])

      not is_nil(opts[:reason]) ->
        resp =
          resp
          |> Map.put(:status, :failed)
          |> Map.put(:reason, opts[:reason])

        case opts[:details] do
          nil -> resp
          x -> Map.put(resp, :details, x)
        end

      true ->
        Map.put(resp, :status, :success)
    end
  end

  def event(command_id, data \\ nil) do
    request(command_id, data) |> Map.put(:type, :event)
  end

  def send_request(client, command_id, data \\ nil) do
    WSC.send_message(client, {:text, request(command_id, data) |> Jason.encode!()})
  end

  def send_response(client, request, opts \\ []) do
    WSC.send_message(
      client,
      {:text, response(request, opts) |> Jason.encode!()}
    )
  end

  def send_event(client, command_id, data \\ nil) do
    WSC.send_message(client, {:text, event(command_id, data) |> Jason.encode!()})
  end

  # TODO tachyon_mvp: create a version of this function that also check the
  # the response against the expected json schema
  def recv_message(client, opts \\ []) do
    opts = Keyword.put_new(opts, :timeout, 300)

    case WSC.recv(client, opts) do
      {:ok, {:text, resp}} ->
        with decoded <- Jason.decode!(resp),
             {:ok, cmd_id, message_type, _msg_id} <-
               Teiserver.Tachyon.Schema.parse_envelope(decoded),
             :ok <- Teiserver.Tachyon.Schema.parse_message(cmd_id, message_type, decoded) do
          {:ok, decoded}
        else
          {:error, %JsonXema.ValidationError{} = err} ->
            IO.inspect(Jason.decode!(resp), label: "schema validation failed on")
            {:error, err}

          err ->
            IO.inspect(Jason.decode!(resp), label: "schema validation failed on")
            IO.inspect(err, label: "unknown error")
            err
        end

      other ->
        other
    end
  end

  def recv_message!(client, opts \\ []) do
    {:ok, resp} = recv_message(client, opts)
    resp
  end

  @doc """
  simple function to receive all message for a connection. Returns the list of
  received messages when there's the first timeout.
  """
  def drain(client, recv_opts \\ []) do
    drain(client, recv_opts, [])
  end

  defp drain(client, recv_opts, messages) do
    case recv_message(client, recv_opts) do
      {:ok, msg} -> drain(client, recv_opts, [msg | messages])
      {:error, :timeout} -> Enum.reverse(messages)
    end
  end

  @doc """
  Cleanly disconnect a client by sending a disconnect message before closing
  the connection.
  """
  def disconnect!(client) do
    req = request("system/disconnect")
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    :ok = WSC.disconnect(client)
  end

  @doc """
  Close the underlying websocket connection without sending the proper message.
  This can be used to simulate a player crash.
  """
  def abrupt_disconnect!(client) do
    :ok = WSC.disconnect(client)
  end

  @doc """
  high level function to get the list of matchmaking queues
  """
  def list_queues!(client) do
    req = request("matchmaking/list")
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    {:ok, resp} = recv_message(client)

    message_id = req.messageId

    # This checks the server replies with the correct message_id
    # it only needs to be done once in the test suite so might as well put
    # put it here since this is the first request implemented
    # This could (should?) be moved elsewhere later
    %{
      "type" => "response",
      "messageId" => ^message_id,
      "commandId" => "matchmaking/list",
      "status" => "success"
    } = resp

    resp
  end

  def join_queues!(client, queue_ids) do
    req = request("matchmaking/queue", %{queues: queue_ids})
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    {:ok, resp} = recv_message(client)
    resp
  end

  def leave_queues!(client) do
    req = request("matchmaking/cancel")
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    {:ok, resp} = recv_message(client)
    resp
  end

  def matchmaking_ready!(client) do
    req = request("matchmaking/ready")
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    {:ok, resp} = recv_message(client)
    resp
  end

  def server_stats!(client) do
    req = request("system/serverStats")
    :ok = WSC.send_message(client, {:text, req |> Jason.encode!()})
    {:ok, resp} = recv_message(client)
    resp
  end

  def send_message!(client, message, target) do
    :ok =
      send_request(client, "messaging/send", %{
        message: message,
        target: target
      })

    {:ok, resp} = recv_message(client)
    resp
  end

  def send_dm!(client, message, player_id) do
    send_message!(client, message, %{type: "player", userId: to_string(player_id)})
  end

  def send_party_message(client, message) do
    send_message!(client, message, %{type: :party})
  end

  def subscribe_messaging!(client, opts \\ []) do
    since = Keyword.get(opts, :since, %{type: "latest"})
    :ok = send_request(client, "messaging/subscribeReceived", %{since: since})
    recv_message!(client)
  end

  def user_info!(client, user_id) do
    :ok = send_request(client, "user/info", %{userId: to_string(user_id)})
    {:ok, resp} = recv_message(client)
    resp
  end

  def friend_list!(client) do
    :ok = send_request(client, "friend/list")
    recv_message!(client)
  end

  def send_friend_request!(client, user_id) do
    :ok = send_request(client, "friend/sendRequest", %{to: to_string(user_id)})
    recv_message!(client)
  end

  def accept_friend_request!(client, from_id) do
    :ok = send_request(client, "friend/acceptRequest", %{from: to_string(from_id)})
    recv_message!(client)
  end

  def reject_friend_request!(client, from_id) do
    :ok = send_request(client, "friend/rejectRequest", %{from: to_string(from_id)})
    recv_message!(client)
  end

  def cancel_friend_request!(client, user_id) do
    :ok = send_request(client, "friend/cancelRequest", %{to: to_string(user_id)})
    recv_message!(client)
  end

  def remove_friend!(client, friend_id) do
    :ok = send_request(client, "friend/remove", %{userId: to_string(friend_id)})
    recv_message!(client)
  end

  def subscribe_updates!(client, user_ids) do
    :ok =
      send_request(client, "user/subscribeUpdates", %{userIds: Enum.map(user_ids, &to_string/1)})

    {:ok, resp} = recv_message(client)
    resp
  end

  def unsubscribe_updates!(client, user_ids) do
    :ok = send_request(client, "user/unsubscribeUpdates", %{userIds: user_ids})
    {:ok, resp} = recv_message(client)
    resp
  end

  def create_party!(client) do
    :ok = send_request(client, "party/create")
    {:ok, resp} = recv_message(client)
    resp
  end

  def leave_party!(client) do
    :ok = send_request(client, "party/leave")
    {:ok, resp} = recv_message(client)
    resp
  end

  def invite_to_party!(client, user_id) do
    :ok = send_request(client, "party/invite", %{userId: to_string(user_id)})
    {:ok, resp} = recv_message(client)
    resp
  end

  def accept_party_invite!(client, party_id) do
    :ok = send_request(client, "party/acceptInvite", %{partyId: party_id})
    {:ok, resp} = recv_message(client)
    resp
  end

  def decline_party_invite!(client, party_id) do
    :ok = send_request(client, "party/declineInvite", %{partyId: party_id})
    {:ok, resp} = recv_message(client)
    resp
  end

  def cancel_party_invite!(client, user_id) do
    :ok = send_request(client, "party/cancelInvite", %{userId: to_string(user_id)})
    {:ok, resp} = recv_message(client)
    resp
  end

  def kick_player_from_party!(client, target_id) do
    :ok = send_request(client, "party/kickMember", %{userId: to_string(target_id)})
    {:ok, resp} = recv_message(client)
    resp
  end

  def autohost_send_update_event(client, data) do
    :ok = send_event(client, "autohost/update", data)
  end

  def autohost_engine_quit(battle_id),
    do: %{
      battleId: battle_id,
      time: DateTime.utc_now() |> DateTime.to_unix(:microsecond),
      update: %{type: :engine_quit}
    }
end
