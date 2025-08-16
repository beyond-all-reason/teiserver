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
end
