defmodule TeiserverWeb.Tachyon.LobbyTest do
  use TeiserverWeb.ConnCase

  alias Teiserver.Support.Tachyon

  setup [:setup_assets, {Tachyon, :setup_client}]

  describe "create lobby" do
    test "can create lobby", %{client: client, user: user} do
      lobby_data = %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }

      %{"status" => "success", "data" => data} = Tachyon.create_lobby!(client, lobby_data)
      user_id = to_string(user.id)
      %{"id" => ^user_id} = data["players"][user_id]
      player_data = data["players"][user_id]
      assert is_map_key(data["allyTeamConfig"], player_data["allyTeam"])

      assert is_map_key(
               data["allyTeamConfig"][player_data["allyTeam"]]["teams"],
               player_data["team"]
             )
    end

    test "cannot create lobby when already in lobby", %{client: client} do
      lobby_data = %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }

      %{"status" => "success"} = Tachyon.create_lobby!(client, lobby_data)

      lobby_data2 = Map.put(lobby_data, :name, "other lobby")

      %{"status" => "failed", "reason" => "invalid_request", "details" => "already_in_lobby"} =
        Tachyon.create_lobby!(client, lobby_data2)
    end
  end

  describe "join lobby" do
    setup [:setup_lobby]

    test "works", %{user: user, lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success", "data" => data} = Tachyon.join_lobby!(ctx2[:client], lobby_id)
      assert is_map_key(data["players"], to_string(user.id))
      assert is_map_key(data["spectators"], to_string(ctx2[:user].id))
    end

    test "is idempotent", %{client: client, lobby_id: lobby_id} do
      %{"status" => "success"} = Tachyon.join_lobby!(client, lobby_id)
      %{"status" => "success"} = Tachyon.join_lobby!(client, lobby_id)
    end

    test "must provide valid lobby id", %{client: client} do
      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.join_lobby!(client, "definitely-not-the-lobby-id")
    end

    test "doesn't work if already in another lobby", %{lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()

      lobby_data = %{
        name: "other lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }

      %{"status" => "success"} = Tachyon.create_lobby!(ctx2[:client], lobby_data)

      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.join_lobby!(ctx2[:client], lobby_id)
    end

    test "ally team full", %{lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success"} = Tachyon.join_lobby!(ctx2[:client], lobby_id)

      %{"status" => "failed", "reason" => "ally_team_full"} =
        Tachyon.join_ally_team!(ctx2[:client], "000")
    end

    test "members get updated events on join", %{client: client, lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success", "data" => _details} = Tachyon.join_lobby!(ctx2[:client], lobby_id)
      %{"commandId" => "lobby/updated", "data" => data} = Tachyon.recv_message!(client)
      assert is_map_key(data["spectators"], to_string(ctx2[:user].id))
    end
  end

  describe "leave lobby" do
    setup [:setup_lobby]

    test "works", %{client: client} do
      %{"status" => "success"} = Tachyon.leave_lobby!(client)
    end

    test "must be in lobby" do
      {:ok, ctx2} = Tachyon.setup_client()

      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.leave_lobby!(ctx2[:client])
    end

    test "remaining members get updated events", %{client: client, lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success"} = Tachyon.join_lobby!(ctx2[:client], lobby_id)
      %{"commandId" => "lobby/updated"} = Tachyon.recv_message!(client)
      %{"status" => "success"} = Tachyon.leave_lobby!(ctx2[:client])
      %{"commandId" => "lobby/updated", "data" => data} = Tachyon.recv_message!(client)
      assert data["spectators"][to_string(ctx2[:user].id)] == nil
    end
  end

  describe "spectate" do
    setup [:setup_lobby]

    test "works", %{client: client, user: user} do
      %{"status" => "success"} = Tachyon.spectate!(client)

      %{"commandId" => "lobby/updated", "data" => data} = Tachyon.recv_message!(client)

      user_id = to_string(user.id)

      %{
        "players" => %{^user_id => nil},
        "spectators" => %{^user_id => %{"id" => ^user_id, "joinQueuePosition" => nil}}
      } = data
    end
  end

  describe "start battle" do
    setup [
      {Tachyon, :setup_app},
      {Tachyon, :setup_autohost},
      :setup_lobby
    ]

    test "must be in lobby" do
      {:ok, ctx2} = Tachyon.setup_client()

      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.lobby_start_battle!(ctx2[:client])
    end

    test "battle lifecycle", ctx do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success"} = Tachyon.join_lobby!(ctx2[:client], ctx[:lobby_id])
      %{"commandId" => "lobby/updated"} = Tachyon.recv_message!(ctx[:client])

      Tachyon.send_request(ctx[:client], "lobby/startBattle", %{id: ctx[:lobby_id]})

      %{"commandId" => "autohost/start"} =
        start_req = Tachyon.recv_message!(ctx[:autohost_client])

      uid2 = to_string(ctx2[:user].id)
      [%{"userId" => ^uid2}] = start_req["data"]["spectators"]

      start_req_response = %{
        port: 32781,
        ips: ["127.0.0.1"]
      }

      Tachyon.send_response(ctx[:autohost_client], start_req, data: start_req_response)

      %{"status" => "success", "commandId" => "lobby/startBattle"} =
        Tachyon.recv_message!(ctx[:client])

      # client should then receive a request to start a battle from server
      %{"commandId" => "battle/start", "type" => "request"} =
        req = Tachyon.recv_message!(ctx[:client])

      Tachyon.send_response(ctx[:client], req)

      # and also an update message
      %{"commandId" => "lobby/updated", "data" => updated} = Tachyon.recv_message!(ctx[:client])
      %{"currentBattle" => %{"startedAt" => _, "id" => battle_id}} = updated

      # can't start a battle when one is ongoing
      %{
        "status" => "failed",
        "reason" => "invalid_request",
        "details" => "battle_already_started"
      } =
        Tachyon.lobby_start_battle!(ctx[:client])

      # new client should see there's a battle ongoing
      {:ok, ctx3} = Tachyon.setup_client()

      %{"status" => "success", "data" => data} =
        Tachyon.join_lobby!(ctx3[:client], ctx[:lobby_id])

      %{"commandId" => "lobby/updated"} = Tachyon.recv_message!(ctx[:client])

      %{"currentBattle" => %{"startedAt" => _start_ts}} = data

      # when battle terminates members should get notified
      Teiserver.TachyonBattle.lookup(battle_id) |> Process.exit(:kill)
      %{"commandId" => "lobby/updated", "data" => updated} = Tachyon.recv_message!(ctx[:client])
      %{"currentBattle" => nil} = updated
    end
  end

  describe "listing" do
    setup [
      {Tachyon, :setup_app},
      {Tachyon, :setup_autohost}
    ]

    test "subscribe list updates", %{client: client} do
      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)

      %{"commandId" => "lobby/listReset", "data" => %{"lobbies" => %{}}} =
        Tachyon.recv_message!(client)

      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()

      {:ok, lobby_id: lobby_id} =
        setup_lobby(%{client: ctx2[:client]}, %{
          ally_team_config: Tachyon.mk_ally_team_config(2, 2)
        })

      %{
        "commandId" => "lobby/listUpdated",
        "data" => %{
          "lobbies" => lobbies
        }
      } = Tachyon.recv_message!(client)

      assert lobbies[lobby_id]["maxPlayerCount"] == 4

      {:ok, ctx3} = Tachyon.setup_client()
      %{"status" => "success", "data" => data} = Tachyon.join_lobby!(ctx3[:client], lobby_id)
      assert is_map_key(data["allyTeamConfig"], "000")
      %{"status" => "success"} = Tachyon.join_ally_team!(ctx3[:client], "000")
      %{"commandId" => "lobby/updated"} = Tachyon.recv_message!(ctx3[:client])

      %{"commandId" => "lobby/listUpdated", "data" => %{"lobbies" => lobbies}} =
        Tachyon.recv_message!(client)

      assert lobbies[lobby_id] ==
               %{
                 "id" => lobby_id,
                 "playerCount" => 2,
                 "currentBattle" => nil
               }

      %{"status" => "success"} = Tachyon.leave_lobby!(ctx3[:client])

      %{
        "commandId" => "lobby/listUpdated",
        "data" => %{
          "lobbies" => lobbies
        }
      } = Tachyon.recv_message!(client)

      assert lobbies[lobby_id]["playerCount"] == 1

      Tachyon.drain(ctx2[:client])
      %{"status" => "success"} = Tachyon.leave_lobby!(ctx2[:client])

      %{"commandId" => "lobby/listUpdated", "data" => %{"lobbies" => lobbies}} =
        Tachyon.recv_message!(client)

      assert is_map_key(lobbies, lobby_id)
      assert lobbies[lobby_id] == nil
    end

    test "unsubscribe list updates", %{client: client} do
      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)

      %{"commandId" => "lobby/listReset", "data" => %{"lobbies" => %{}}} =
        Tachyon.recv_message!(client)

      %{"status" => "success"} = Tachyon.unsubscribe_lobby_list!(client)

      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()

      {:ok, lobby_id: _lobby_id} =
        setup_lobby(%{client: ctx2[:client]}, %{
          ally_team_config: Tachyon.mk_ally_team_config(2, 2)
        })

      # make sure no updates are sent
      assert {:error, :timeout} = Tachyon.recv_message(client)
    end

    test "start battle", %{client: client} = ctx do
      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)
      %{"commandId" => "lobby/listReset"} = Tachyon.recv_message!(client)

      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()
      {:ok, lobby_id: lobby_id} = setup_lobby(%{client: ctx2[:client]})

      %{"commandId" => "lobby/listUpdated"} = Tachyon.recv_message!(client)

      # simulate starting the battle
      Tachyon.send_request(ctx2[:client], "lobby/startBattle", %{id: ctx2[:lobby_id]})

      %{"commandId" => "autohost/start"} =
        start_req = Tachyon.recv_message!(ctx[:autohost_client])

      start_req_response = %{
        port: 32781,
        ips: ["127.0.0.1"]
      }

      Tachyon.send_response(ctx[:autohost_client], start_req, data: start_req_response)

      %{"status" => "success", "commandId" => "lobby/startBattle"} =
        Tachyon.recv_message!(ctx2[:client])

      %{"commandId" => "lobby/listUpdated", "data" => %{"lobbies" => update}} =
        Tachyon.recv_message!(client)

      assert update[lobby_id]["currentBattle"]["startedAt"] != nil
      assert update[lobby_id]["id"] == lobby_id

      # bit of a hack to get the battle id :/
      {:ok, %{current_battle: %{id: battle_id}}} =
        Teiserver.TachyonLobby.Lobby.get_details(lobby_id)

      # get update when battle terminates
      Teiserver.TachyonBattle.lookup(battle_id) |> Process.exit(:kill)

      %{"commandId" => "lobby/listUpdated", "data" => %{"lobbies" => update}} =
        Tachyon.recv_message!(client)

      assert update[lobby_id]["currentBattle"] == nil
    end

    test "list reset", %{client: client} do
      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()

      {:ok, lobby_id: lobby_id} =
        setup_lobby(%{client: ctx2[:client]}, %{
          ally_team_config: Tachyon.mk_ally_team_config(2, 2)
        })

      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)

      %{"commandId" => "lobby/listReset", "data" => %{"lobbies" => lobbies}} =
        Tachyon.recv_message!(client)

      assert is_map_key(lobbies, lobby_id)

      Process.whereis(Teiserver.TachyonLobby.List)
      |> Process.exit(:kill)

      %{"commandId" => "lobby/listReset", "data" => %{"lobbies" => lobbies2}} =
        Tachyon.recv_message!(client)

      assert lobbies == lobbies2
    end

    test "avoid duplicate subscription", %{client: client} do
      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()

      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)

      %{"commandId" => "lobby/listReset"} = Tachyon.recv_message!(client)

      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)

      # still get the full list on subsequent subscribes
      %{"commandId" => "lobby/listReset"} = Tachyon.recv_message!(client)

      {:ok, _} =
        setup_lobby(%{client: ctx2[:client]}, %{
          ally_team_config: Tachyon.mk_ally_team_config(2, 2)
        })

      %{"commandId" => "lobby/listUpdated"} = Tachyon.recv_message!(client)
      {:error, :timeout} = Tachyon.recv_message(client)
    end
  end

  test "get lobby/left event when lobby dies", ctx do
    {:ok, lobby_id: lobby_id} = setup_lobby(ctx)
    lobby_pid = Teiserver.TachyonLobby.lookup(lobby_id)
    assert is_pid(lobby_pid)
    Process.exit(lobby_pid, :kill)

    %{"commandId" => "lobby/left"} = Tachyon.recv_message!(ctx[:client])

    # can create another lobby afterwards (session state is cleaned)
    {:ok, _} = setup_lobby(ctx)
  end

  defp setup_lobby(%{client: client}, overrides \\ %{}) do
    lobby_data =
      %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }
      |> Map.merge(overrides)

    %{"status" => "success", "data" => %{"id" => lobby_id}} =
      Tachyon.create_lobby!(client, lobby_data)

    {:ok, lobby_id: lobby_id}
  end

  defp setup_assets(_ctx) do
    game = Teiserver.AssetFixtures.create_game(%{name: "test-lobby-game", in_matchmaking: true})

    engine =
      Teiserver.AssetFixtures.create_engine(%{name: "test-lobby-engine", in_matchmaking: true})

    {:ok, game: game, engine: engine}
  end
end
