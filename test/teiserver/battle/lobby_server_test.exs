defmodule Teiserver.Battle.LobbyServerTest do
  @moduledoc false
  # Cannot be async because some other tests will call for a list of all lobbies
  use Teiserver.DataCase, async: false
  alias Teiserver.Lobby.LobbyLib
  alias Teiserver.Coordinator

  @tag :needs_attention
  test "server test" do
    host = Teiserver.TeiserverTestLib.new_user()

    lobby = %{
      id: 123,
      founder_id: host.id,
      founder_name: host.name,
      cmd: "c.lobby.create",
      name: "LobbyServerTest",
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

    p = LobbyLib.start_lobby_server(lobby)
    assert is_pid(p)

    # Call it!
    c = LobbyLib.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.port == 1234
    assert c.map_name == "koom valley"

    # Call one that doesn't exist
    c = LobbyLib.call_lobby(-1, :get_lobby_state)
    assert c == nil

    # Partial update
    r = LobbyLib.update_lobby_values(lobby_id, %{map_name: "new map name"})
    assert r == :ok

    # Partial update with no lobby server
    r = LobbyLib.update_lobby_values(-1, %{map_name: "new map name"})
    assert r == nil

    # Update lobby
    LobbyLib.update_lobby(Map.put(lobby, :engine_name, "new engie"), nil, :reason)

    # No server
    # r = LobbyLib.update_lobby(Map.merge(lobby, %{engine_name: "new engie", id: -1}), nil, :reason)

    LobbyLib.stop_lobby_server(lobby_id)
  end

  test "rename test" do
    host = Teiserver.TeiserverTestLib.new_user()

    lobby = %{
      id: 123,
      founder_id: host.id,
      founder_name: host.name,
      cmd: "c.lobby.create",
      name: "LobbyServerTestRename",
      base_name: "LobbyServerTestRename",
      nattype: "none",
      type: "normal",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      teaser: "",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      },
      password: nil,
      module: to_string(__MODULE__)
    }

    lobby_id = lobby.id

    p = LobbyLib.start_lobby_server(lobby)
    Coordinator.start_consul(lobby_id)
    assert is_pid(p)
    assert LobbyLib.lobby_exists?(lobby_id) == true

    LobbyLib.rename_lobby(lobby_id, "base name", host.id)
    c = LobbyLib.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.name == "base name"

    # Now set a max rating
    Coordinator.cast_consul(lobby_id, {:put, :maximum_rating_to_play, 50})
    LobbyLib.cast_lobby(lobby_id, :refresh_name)

    c = LobbyLib.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.name == "base name | Max rating: 50"

    # Now set a min rating
    Coordinator.cast_consul(lobby_id, {:put, :minimum_rating_to_play, 10})
    LobbyLib.cast_lobby(lobby_id, :refresh_name)

    c = LobbyLib.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.name == "base name | Rating: 10-50"

    # Try renaming with nil user
    LobbyLib.rename_lobby(lobby_id, "other name", nil)
    c = LobbyLib.call_lobby(lobby_id, :get_lobby_state)
    assert c.id == lobby_id
    assert c.name == "other name | Rating: 10-50"

    LobbyLib.stop_lobby_server(lobby_id)
    assert LobbyLib.lobby_exists?(lobby_id) == false
  end
end
