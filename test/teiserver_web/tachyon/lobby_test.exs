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
end
