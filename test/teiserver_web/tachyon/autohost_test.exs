defmodule TeiserverWeb.Tachyon.Autohost do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.OAuthFixtures
  alias Teiserver.Support.Tachyon
  import Teiserver.Support.Polling, only: [poll_until_some: 1, poll_until: 2, poll_until: 3]
  alias WebsocketSyncClient, as: WSC

  def create_autohost() do
    name = for _ <- 1..20, into: "", do: <<Enum.random(?a..?z)>>
    create_autohost(name)
  end

  def create_autohost(name), do: Teiserver.BotFixtures.create_bot(name)

  def setup_autohost(_context), do: {:ok, autohost: Teiserver.BotFixtures.create_bot()}

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
      |> Map.put(:bot_id, context.autohost.id)
      |> OAuthFixtures.create_token()

    {:ok, creds: creds, token: token}
  end

  def setup_client(context), do: {:ok, client: Tachyon.connect(context.token)}

  setup [:setup_app, :setup_autohost, :setup_token]

  test "must send `status` as first message", %{token: token} do
    client = Tachyon.connect(token)

    assert %{"type" => "request", "commandId" => "autohost/subscribeUpdates"} =
             Tachyon.recv_message!(client)

    req = Tachyon.request("matchmaking/list") |> Jason.encode!()

    assert :ok == WSC.send_message(client, {:text, req})
    assert %{"status" => "failed", "reason" => "invalid_request"} = Tachyon.recv_message!(client)
    assert {:error, :disconnected} = WSC.send_message(client, {:text, req})
  end

  test "can lookup after status message", %{token: token} do
    Tachyon.connect_autohost!(token, 10, 0)

    {pid, %{max_battles: 10, current_battles: 0}} =
      poll_until_some(fn -> Teiserver.Autohost.lookup_autohost(token.bot_id) end)

    assert is_pid(pid)
  end

  test "can update status attributes", %{token: token} do
    client = Tachyon.connect_autohost!(token, 10, 0)

    {_, %{max_battles: 10, current_battles: 0}} =
      poll_until_some(fn -> Teiserver.Autohost.lookup_autohost(token.bot_id) end)

    :ok = Tachyon.send_event(client, "autohost/status", %{maxBattles: 15, currentBattles: 3})

    {_, %{max_battles: 15, current_battles: 3}} =
      poll_until(
        fn -> Teiserver.Autohost.lookup_autohost(token.bot_id) end,
        fn {_, details} ->
          details != nil && details.max_battles == 15 && details.current_battles == 3
        end,
        wait: 5
      )
  end

  test "can list connected autohosts", %{app: app, autohost: autohost, token: token} do
    other_autohost = create_autohost()
    {:ok, creds: _, token: other_token} = setup_token(%{app: app, autohost: other_autohost})

    # make sure the other tests aren't interfering
    poll_until(&Teiserver.Autohost.list/0, fn l -> Enum.empty?(l) end)

    Tachyon.connect_autohost!(token, 10, 0)
    Tachyon.connect_autohost!(other_token, 15, 1)

    list =
      poll_until(&Teiserver.Autohost.list/0, fn l -> Enum.count(l) == 2 end)
      |> MapSet.new()

    expected =
      MapSet.new([
        %{id: autohost.id, max_battles: 10, current_battles: 0},
        %{id: other_autohost.id, max_battles: 15, current_battles: 1}
      ])

    assert list == expected
  end
end
