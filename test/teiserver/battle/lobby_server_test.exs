defmodule Teiserver.Battle.LobbyServerTest do
  # Cannot be async because some other tests will call for a list of all lobbies
  use Central.DataCase, async: false
  alias Teiserver.Battle.LobbyCache

  test "server test" do
    lobby = %{
      id: 123,
      cmd: "c.lobby.create",
      name: "ServerName",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }

    lobby_id = lobby.id

    p = LobbyCache.start_lobby_server(lobby)
    assert is_pid(p)

    # Call it!
    c = LobbyCache.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.port == 1234
    assert c.map_name == "koom valley"

    # Call one that doesn't exist
    c = LobbyCache.call_lobby(-1, :get_lobby_state)
    assert c == nil

    # Partial update
    r = LobbyCache.update_lobby_values(lobby_id, %{map_name: "new map name"})
    assert r == :ok

    # Partial update with no lobby server
    r = LobbyCache.update_lobby_values(-1, %{map_name: "new map name"})
    assert r == nil


    # Update lobby
    r = LobbyCache.update_lobby(Map.put(lobby, :engine_name, "new engie"), nil, :reason)
    assert r != nil

    # No server
    # r = LobbyCache.update_lobby(Map.merge(lobby, %{engine_name: "new engie", id: -1}), nil, :reason)
    # assert r == nil

    LobbyCache.stop_lobby_server(lobby_id)
  end
end
