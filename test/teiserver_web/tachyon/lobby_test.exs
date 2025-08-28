defmodule TeiserverWeb.Tachyon.LobbyTest do
  use TeiserverWeb.ConnCase

  alias Teiserver.Support.Tachyon

  describe "create lobby" do
    setup [{Tachyon, :setup_client}]

    test "can create lobby", %{client: client, user: user} do
      lobby_data = %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }

      %{"status" => "success", "data" => data} = Tachyon.create_lobby!(client, lobby_data)
      user_id = to_string(user.id)
      %{"type" => "player", "id" => ^user_id} = data["members"][user_id]
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
    setup [{Tachyon, :setup_client}, :setup_lobby]

    test "works", %{user: user, lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success", "data" => data} = Tachyon.join_lobby!(ctx2[:client], lobby_id)
      assert is_map_key(data["members"], to_string(user.id))
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

    test "members get updated events on join", %{client: client, lobby_id: lobby_id} do
      {:ok, ctx2} = Tachyon.setup_client()
      %{"status" => "success"} = Tachyon.join_lobby!(ctx2[:client], lobby_id)
      %{"commandId" => "lobby/updated", "data" => data} = Tachyon.recv_message!(client)
      assert is_map_key(data["members"][to_string(ctx2[:user].id)], "team")
    end
  end

  describe "leave lobby" do
    setup [{Tachyon, :setup_client}, :setup_lobby]

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
      assert data["members"][to_string(ctx2[:user].id)] == nil
    end
  end

  describe "start battle" do
    setup [
      {Tachyon, :setup_client},
      {Tachyon, :setup_app},
      {Tachyon, :setup_autohost},
      :setup_lobby
    ]

    test "must be in lobby", ctx do
      {:ok, ctx2} = Tachyon.setup_client()

      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.start_lobby_battle!(ctx2[:client], ctx[:lobby_id])
    end

    test "must be in correct lobby", ctx do
      {:ok, ctx2} = Tachyon.setup_client()

      lobby_data = %{
        name: "test lobby",
        map_name: "test-map",
        ally_team_config: Tachyon.mk_ally_team_config(2, 1)
      }

      %{"status" => "success", "data" => %{"id" => other_lobby_id}} =
        Tachyon.create_lobby!(ctx2[:client], lobby_data)

      %{"status" => "failed", "reason" => "invalid_request"} =
        Tachyon.start_lobby_battle!(ctx[:client], other_lobby_id)
    end

    test "can start battle", ctx do
      Tachyon.send_request(ctx[:client], "lobby/startBattle", %{id: ctx[:lobby_id]})

      %{"commandId" => "autohost/start"} =
        start_req = Tachyon.recv_message!(ctx[:autohost_client])

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
    end
  end

  describe "listing" do
    setup [{Tachyon, :setup_client}]

    test "subscribe updates", %{client: client} do
      %{"status" => "success"} = Tachyon.subscribe_lobby_list!(client)
      %{"commandId" => "lobby/listUpdated", "data" => data} = Tachyon.recv_message!(client)
      assert data["updates"] == [%{"type" => "setList", "overviews" => []}]

      # create lobby with another client so that only list updates are sent to
      # the original client, it makes the tests a bit simpler
      {:ok, ctx2} = Tachyon.setup_client()
      {:ok, lobby_id: lobby_id} = setup_lobby(%{client: ctx2[:client]})

      %{
        "commandId" => "lobby/listUpdated",
        "data" => %{
          "updates" => [
            %{
              "type" => "added",
              "overview" => %{"id" => ^lobby_id}
            }
          ]
        }
      } = Tachyon.recv_message!(client)

      {:ok, ctx3} = Tachyon.setup_client()
      %{"status" => "success"} = Tachyon.join_lobby!(ctx3[:client], lobby_id)

      %{"commandId" => "lobby/listUpdated", "data" => data} = Tachyon.recv_message!(client)

      assert data["updates"] == [
               %{
                 "type" => "updated",
                 "overview" => %{
                   "id" => lobby_id,
                   "playerCount" => 2,
                   "currentBattle" => nil
                 }
               }
             ]

      %{"status" => "success"} = Tachyon.leave_lobby!(ctx3[:client])

      %{
        "commandId" => "lobby/listUpdated",
        "data" => %{
          "updates" => [
            %{
              "overview" => %{"id" => ^lobby_id, "playerCount" => 1}
            }
          ]
        }
      } = Tachyon.recv_message!(client)

      Tachyon.drain(ctx2[:client])
      %{"status" => "success"} = Tachyon.leave_lobby!(ctx2[:client])

      %{"commandId" => "lobby/listUpdated", "data" => data} = Tachyon.recv_message!(client)
      assert data["updates"] == [%{"id" => lobby_id, "type" => "removed"}]
    end
  end

  defp setup_lobby(%{client: client}) do
    lobby_data = %{
      name: "test lobby",
      map_name: "test-map",
      ally_team_config: Tachyon.mk_ally_team_config(2, 1)
    }

    %{"status" => "success", "data" => %{"id" => lobby_id}} =
      Tachyon.create_lobby!(client, lobby_data)

    {:ok, lobby_id: lobby_id}
  end
end
