defmodule Teiserver.Protocols.V1.TachyonSystemTest do
  use Central.ServerCase
  alias Teiserver.{Battle, Account}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, new_user: 0]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()

    {:ok,
      socket: socket,
      user: user,
      pid: pid
    }
  end

  test "ping", %{socket: socket} do
    _tachyon_send(socket, %{"cmd" => "c.system.ping"})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.system.pong"
    assert is_integer(resp["time"])
  end

  test "watch - no channel", %{socket: socket} do
    _tachyon_send(socket, %{"cmd" => "c.system.watch", "channel" => "not a channel"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.watch",
      "result" => "failure",
      "channel" => "not a channel",
      "reason" => "No channel"
    }

    _tachyon_send(socket, %{"cmd" => "c.system.unwatch", "channel" => "not a channel"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.unwatch",
      "result" => "failure",
      "channel" => "not a channel",
      "reason" => "No channel"
    }
  end

  test "watch - server_stats", %{socket: socket} do
    _tachyon_send(socket, %{"cmd" => "c.system.watch", "channel" => "server_stats"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.watch",
      "result" => "success",
      "channel" => "server_stats"
    }
    assert _tachyon_recv(socket) == :timeout

    # Trigger chanel
    send(Teiserver.Telemetry.TelemetryServer, :tick)

    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.server_stats",
      "data" => %{
        "in_progresss_lobby_count" => 0,
        "lobby_count" => 0,
        "player_count" => 0,
        "user_count" => 1
        }
      }

    _tachyon_send(socket, %{"cmd" => "c.system.unwatch", "channel" => "server_stats"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.unwatch",
      "result" => "success",
      "channel" => "server_stats"
    }
    assert _tachyon_recv(socket) == :timeout

    # Trigger chanel
    send(Teiserver.Telemetry.TelemetryServer, :tick)

    assert _tachyon_recv(socket) == :timeout
  end

  test "watch - all_lobbies", %{socket: socket} do
    bot_user = new_user()
    bot_user = Account.update_cache_user(%{bot_user | bot: true})

    _tachyon_send(socket, %{"cmd" => "c.system.watch", "channel" => "all_lobbies"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.watch",
      "result" => "success",
      "channel" => "all_lobbies"
    }
    assert _tachyon_recv(socket) == :timeout

    # Trigger chanel
    lobby = Battle.Lobby.create_lobby(%{
      founder_id: bot_user.id,
      founder_name: bot_user.name,
      name: "lobby_chat_test_as_bot",
      id: 1
    })
    |> Battle.add_lobby

    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.lobby.opened",
      "lobby" => %{
        "disabled_units" => [], "engine_name" => "spring", "engine_version" => nil, "founder_id" => bot_user.id, "game_name" => nil, "id" => 1, "in_progress" => false, "ip" => nil, "locked" => false, "map_hash" => nil, "map_name" => nil, "max_players" => 16, "name" => "lobby_chat_test_as_bot", "passworded" => false, "players" => [], "public" => true, "start_areas" => %{}, "started_at" => nil, "type" => "normal"
        }
      }

    # Close the lobby
    Battle.close_lobby(lobby.id)
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.lobby.closed",
      "lobby_id" => lobby.id
    }

    _tachyon_send(socket, %{"cmd" => "c.system.unwatch", "channel" => "all_lobbies"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.unwatch",
      "result" => "success",
      "channel" => "all_lobbies"
    }
    assert _tachyon_recv(socket) == :timeout

    # Trigger chanel by opening a new one
    lobby = Battle.Lobby.create_lobby(%{
      founder_id: bot_user.id,
      founder_name: bot_user.name,
      name: "lobby_chat_test_as_bot",
      id: 1
    })
    |> Battle.add_lobby

    assert _tachyon_recv(socket) == :timeout

    # Close it to be sure
    Battle.close_lobby(lobby.id)

    assert _tachyon_recv(socket) == :timeout
  end

  test "watch - lobby:xxx", %{socket: socket} do
    bot_user = new_user()
    bot_user = Account.update_cache_user(%{bot_user | bot: true})

    lobby = Battle.Lobby.create_lobby(%{
      founder_id: bot_user.id,
      founder_name: bot_user.name,
      name: "lobby_chat_test_as_bot",
      id: 1
    })
    |> Battle.add_lobby

    _tachyon_send(socket, %{"cmd" => "c.system.watch", "channel" => "lobby:#{lobby.id}"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.watch",
      "result" => "success",
      "channel" => "lobby:#{lobby.id}"
    }
    assert _tachyon_recv(socket) == :timeout

    # Cause this to trigger
    Battle.update_lobby_values(lobby.id, %{map_name: "New map name"})

    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.lobby.update_values",
      "lobby_id" => 1,
      "new_values" => %{"map_name" => "New map name"}
    }

    _tachyon_send(socket, %{"cmd" => "c.system.unwatch", "channel" => "lobby:#{lobby.id}"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.system.unwatch",
      "result" => "success",
      "channel" => "lobby:#{lobby.id}"
    }
    assert _tachyon_recv(socket) == :timeout

    # Trigger again
    Battle.update_lobby_values(lobby.id, %{map_name: "Another map name"})
    assert _tachyon_recv(socket) == :timeout

    Battle.close_lobby(lobby.id)
  end
end
