defmodule Teiserver.Support.Tachyon do
  alias WebsocketSyncClient, as: WSC
  alias Teiserver.OAuthFixtures

  def setup_client(_context), do: setup_client()

  def setup_client() do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    %{client: client, token: token} = connect(user)

    ExUnit.Callbacks.on_exit(fn -> WSC.disconnect(client) end)
    {:ok, user: user, client: client, token: token}
  end

  @doc """
  connects the given user and returns the ws client
  """
  def connect(%Teiserver.OAuth.Token{} = token) do
    opts = connect_options(token)

    {:ok, client} = WSC.connect(tachyon_url(), opts)
    client
  end

  def connect(user) do
    %{token: token} = OAuthFixtures.setup_token(user)

    client = connect(token)
    %{client: client, token: token}
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

  def event(command_id, data \\ nil) do
    request(command_id, data) |> Map.put(:type, :event)
  end

  def send_request(client, command_id, data \\ nil) do
    WSC.send_message(client, {:text, request(command_id, data) |> Jason.encode!()})
  end

  def send_event(client, command_id, data \\ nil) do
    WSC.send_message(client, {:text, event(command_id, data) |> Jason.encode!()})
  end

  # TODO tachyon_mvp: create a version of this function that also check the
  # the response against the expected json schema
  def recv_message(client, opts \\ []) do
    opts = Keyword.put_new(opts, :timeout, 40)

    case WSC.recv(client, opts) do
      {:ok, {:text, resp}} -> {:ok, Jason.decode!(resp)}
      other -> other
    end
  end

  def recv_message!(client, opts \\ []) do
    {:ok, resp} = recv_message(client, opts)
    resp
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

  @doc """
  Run the given function `f` until `pred` returns true on its result.
  Waits `wait` ms between each tries. Raise an error if `pred` returns false
  after `limit` attempts.

  This is often required due to the nature of eventually consistent state and
  lack of control over the beam scheduler.
  """
  @spec poll_until(function(), function(), limit: non_neg_integer(), wait: non_neg_integer()) ::
          term()
  def poll_until(f, pred, opts \\ []) do
    res = f.()

    if pred.(res) do
      res
    else
      limit = Keyword.get(opts, :limit, 10)

      if limit <= 0 do
        raise "poll timeout"
      end

      wait = Keyword.get(opts, :wait, 1)
      :timer.sleep(wait)
      poll_until(f, pred, limit: limit - 1, wait: wait)
    end
  end

  @doc """
  convenience function to poll until f returns a not_nil value
  """
  def poll_until_some(f, opts \\ []) do
    poll_until(f, fn x -> not is_nil(x) end, opts)
  end
end
