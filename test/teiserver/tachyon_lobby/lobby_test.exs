defmodule Teiserver.TachyonLobby.LobbyTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1]
  alias Teiserver.TachyonLobby, as: Lobby

  @moduletag :tachyon

  test "create a lobby" do
    start_params = %{
      creator_user_id: "1234",
      name: "test create lobby",
      map_name: "irrelevant map name",
      ally_team_config: [
        %{
          max_teams: 1,
          start_box: %{top: 0, left: 0, bottom: 1, right: 0.2},
          teams: [%{max_players: 1}]
        },
        %{
          max_teams: 1,
          start_box: %{top: 0, left: 0.8, bottom: 1, right: 1},
          teams: [%{max_players: 1}]
        }
      ]
    }

    {:ok, pid, details} = Lobby.create(start_params)
    p = poll_until_some(fn -> Lobby.lookup(details.id) end)
    assert p == pid
  end
end
