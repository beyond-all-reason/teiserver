defmodule TeiserverWeb.Tachyon.Autohost do
  alias Teiserver.Autohost
  alias Teiserver.BotFixtures
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuthFixtures
  alias Teiserver.Support.Tachyon
  alias WebsocketSyncClient, as: WSC

  use TeiserverWeb.ConnCase, async: false

  import Teiserver.Support.Polling, only: [poll_until: 2, poll_until: 3]

  def create_autohost do
    name = for _i <- 1..20, into: "", do: <<Enum.random(?a..?z)>>
    create_autohost(name)
  end

  def create_autohost(name), do: BotFixtures.create_bot(name)

  def setup_autohost(_context), do: {:ok, autohost: BotFixtures.create_bot()}

  def setup_app(_context) do
    user = GeneralTestLib.make_user(%{"roles" => ["Verified"]})
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

    {_pid, result} =
      poll_until(fn -> Autohost.lookup_autohost(token.bot_id) end, fn {p, details} ->
        details.max_battles == 10 && details.current_battles == 0 && is_pid(p)
      end)

    assert result.max_battles == 10
    assert result.current_battles == 0
  end

  test "can update status attributes", %{token: token} do
    client = Tachyon.connect_autohost!(token, 10, 0)

    poll_until(fn -> Autohost.lookup_autohost(token.bot_id) end, fn {_bot_id, details} ->
      details.max_battles == 10 && details.current_battles == 0
    end)

    :ok = Tachyon.send_event(client, "autohost/status", %{maxBattles: 15, currentBattles: 3})

    {_bot_id, %{max_battles: 15, current_battles: 3}} =
      poll_until(
        fn -> Autohost.lookup_autohost(token.bot_id) end,
        fn {_bot_id, details} ->
          details != nil && details.max_battles == 15 && details.current_battles == 3
        end,
        wait: 5
      )
  end

  test "can list connected autohosts", %{app: app, autohost: autohost, token: token} do
    other_autohost = create_autohost()
    {:ok, creds: _creds, token: other_token} = setup_token(%{app: app, autohost: other_autohost})

    # make sure the other tests aren't interfering
    poll_until(&Autohost.list/0, fn l -> Enum.empty?(l) end)

    Tachyon.connect_autohost!(token, 10, 0)
    Tachyon.connect_autohost!(other_token, 15, 1)

    expected =
      MapSet.new([
        %{id: autohost.id, max_battles: 10, current_battles: 0},
        %{id: other_autohost.id, max_battles: 15, current_battles: 1}
      ])

    poll_until(&Autohost.list/0, fn l ->
      expected == MapSet.new(l)
    end)
  end

  test "autohost start script", %{token: token} do
    client = Tachyon.connect_autohost!(token, 10, 0)

    poll_until(fn -> Autohost.lookup_autohost(token.bot_id) end, fn {_bot_id, details} ->
      details.max_battles == 10 && details.current_battles == 0
    end)

    battle_id = "battle_id"
    pid = self()

    start_script = %{
      engine_version: "engineversion",
      game_name: "game name",
      map_name: "very map",
      start_pos_type: :fixed,
      ally_teams: [
        %{
          teams: [%{players: [%{user_id: 123, name: "player name", password: "123"}]}],
          start_box: %{left: 0, right: 0.4, top: 0, bottom: 0.4}
        },
        %{
          teams: [%{bots: [%{host_user_id: 123, ai_short_name: "testAI", name: "test AI"}]}],
          start_box: %{left: 0.6, right: 1, top: 0.6, bottom: 1}
        }
      ],
      game_options: %{"foo" => "bar"}
    }

    Task.async(fn ->
      Autohost.start_battle(token.bot_id, battle_id, pid, start_script)
    end)

    %{"commandId" => "autohost/start"} = req = Tachyon.recv_message!(client)

    assert req["data"] ==
             %{
               "allyTeams" => [
                 %{
                   "teams" => [
                     %{
                       "players" => [
                         %{"name" => "player name", "password" => "123", "userId" => "123"}
                       ]
                     }
                   ],
                   "startBox" => %{
                     "left" => 0,
                     "right" => 0.4,
                     "top" => 0,
                     "bottom" => 0.4
                   }
                 },
                 %{
                   "teams" => [
                     %{
                       "bots" => [
                         %{"aiShortName" => "testAI", "hostUserId" => "123", "name" => "test AI"}
                       ]
                     }
                   ],
                   "startBox" => %{
                     "left" => 0.6,
                     "right" => 1,
                     "top" => 0.6,
                     "bottom" => 1
                   }
                 }
               ],
               "battleId" => "battle_id",
               "engineVersion" => "engineversion",
               "gameName" => "game name",
               "mapName" => "very map",
               "startPosType" => "fixed",
               "gameOptions" => %{"foo" => "bar"}
             }
  end

  test "can send message and get response", %{token: token} do
    client = Tachyon.connect_autohost!(token, 10, 0)

    poll_until(fn -> Autohost.lookup_autohost(token.bot_id) end, fn {_bot_id, details} ->
      details.max_battles == 10 && details.current_battles == 0
    end)

    battle_id = "battle_id"

    pid = self()

    start_task =
      Task.async(fn ->
        Autohost.start_battle(token.bot_id, battle_id, pid, default_start_script())
      end)

    %{"commandId" => "autohost/start"} = req = Tachyon.recv_message!(client)
    Tachyon.send_response(client, req, data: %{ips: ["1.2.3.4"], port: 1234})

    {:ok, _autohost_pid, _result} = Task.await(start_task)

    task =
      Task.async(fn ->
        Autohost.send_message(token.bot_id, %{battle_id: battle_id, message: "hello"})
      end)

    assert %{"type" => "request", "commandId" => "autohost/sendMessage"} =
             req = Tachyon.recv_message!(client)

    assert req["data"] == %{"battleId" => "battle_id", "message" => "hello"}
    Tachyon.send_response(client, req)
    assert Task.await(task, 150) == :ok
  end

  test "can add a player to a battle", %{token: token} do
    battle_id = "battle_id"
    client = Tachyon.connect_autohost!(token, 10, 0)

    pid = self()

    start_task =
      Task.async(fn ->
        Autohost.start_battle(token.bot_id, battle_id, pid, default_start_script())
      end)

    %{"commandId" => "autohost/start"} = req = Tachyon.recv_message!(client)
    Tachyon.send_response(client, req, data: %{ips: ["1.2.3.4"], port: 1234})
    {:ok, autohost_pid, _data} = Task.await(start_task, 150)

    add_data = %{battle_id: battle_id, user_id: 1234, name: "playername", password: "hunter2"}
    add_task = Task.async(fn -> Autohost.add_player(autohost_pid, add_data) end)
    %{"commandId" => "autohost/addPlayer", "data" => data} = req = Tachyon.recv_message!(client)

    assert data == %{
             "userId" => "1234",
             "battleId" => battle_id,
             "name" => "playername",
             "password" => "hunter2"
           }

    Tachyon.send_response(client, req)
    :ok = Task.await(add_task)
  end

  defp default_start_script do
    %{
      engine_version: "engineversion",
      game_name: "game name",
      map_name: "very map",
      start_pos_type: :fixed,
      ally_teams: [
        %{
          teams: [%{players: [%{user_id: 123, name: "player name", password: "123"}]}]
        }
      ]
    }
  end
end
