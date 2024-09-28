defmodule TeiserverWeb.Tachyon.Autohost do
  use TeiserverWeb.ConnCase
  alias Teiserver.OAuthFixtures
  alias Teiserver.Support.Tachyon
  alias WebsocketSyncClient, as: WSC

  def create_autohost() do
    name = for _ <- 1..20, into: "", do: <<Enum.random(?a..?z)>>
    create_autohost(name)
  end

  def create_autohost(name), do: Teiserver.AutohostFixtures.create_autohost(name)

  def setup_autohost(_context), do: {:ok, autohost: create_autohost()}

  def setup_app(_context) do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    uid = UUID.uuid4()

    app =
      OAuthFixtures.app_attrs(user.id)
      |> Map.merge(%{name: uid, uid: uid})
      |> OAuthFixtures.create_app()

    {:ok, app: app}
  end

  def setup_token(context) do
    creds =
      OAuthFixtures.credential_attrs(context.autohost, context.app.id)
      |> OAuthFixtures.create_credential()

    token =
      OAuthFixtures.token_attrs(nil, context.app)
      |> Map.drop([:owner_id])
      |> Map.put(:autohost_id, context.autohost.id)
      |> OAuthFixtures.create_token()

    {:ok, creds: creds, token: token}
  end

  def setup_client(context), do: {:ok, client: Tachyon.connect(context.token)}

  setup [:setup_app, :setup_autohost, :setup_token]

  test "must send `status` as first message", %{token: token} do
    client = Tachyon.connect(token)
    req = Tachyon.request("matchmaking/list") |> Jason.encode!()

    assert :ok == WSC.send_message(client, {:text, req})
    assert %{"status" => "failed", "reason" => "invalid_request"} = Tachyon.recv_message!(client)
    assert {:error, :disconnected} = WSC.send_message(client, {:text, req})
  end
end
