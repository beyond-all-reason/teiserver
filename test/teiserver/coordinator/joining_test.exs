defmodule Teiserver.Coordinator.JoiningTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener
  alias Teiserver.Coordinator

  alias Teiserver.Client
  alias Teiserver.Account.UserCache

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    %{socket: socket, user: user} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    UserCache.update_user(%{user | moderator: true})
    Client.refresh_client(user.id)

    battle_data = %{
      cmd: "c.lobby.create",
      name: "Coordinator #{:rand.uniform(999_999_999)}",
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
    data = %{cmd: "c.lobby.create", lobby: battle_data}
    _tachyon_send(socket, data)
    reply = _tachyon_recv(socket)
    lobby_id = reply["lobby"]["id"]

    Lobby.start_coordinator_mode(lobby_id)
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{lobby_id}"])

    {:ok, socket: socket, user: user, lobby_id: lobby_id, listener: listener}
  end

  test "welcome message", %{socket: socket, user: user, lobby_id: lobby_id, listener: listener} do
    consul_state = Coordinator.call_consul(lobby_id, :get_all)
    assert consul_state.welcome_message == nil

    data = %{cmd: "c.lobby.message", userid: user.id, message: "!force welcome-message This is the welcome message"}
    _tachyon_send(socket, data)

    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, lobby_id, {user.id, "New welcome message set to: This is the welcome message", lobby_id}, :say}]

    consul_state = Coordinator.call_consul(lobby_id, :get_all)
    assert consul_state.welcome_message == "This is the welcome message"

    # Now a new user joins the battle
    %{socket: socket2, user: user2} = tachyon_auth_setup()
    data = %{cmd: "c.lobby.join", lobby_id: lobby_id}
    _tachyon_send(socket2, data)

    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.join",
      "result" => "waiting_for_host"
    }

    # Accept them
    data = %{cmd: "c.lobby.respond_to_join_request", userid: user2.id, response: "approve"}
    _tachyon_send(socket, data)
    _battle = _tachyon_recv(socket2)

    # Request status message for the player
    status_request = _tachyon_recv(socket2)
    assert status_request["cmd"] == "s.lobby.request_status"

    # Send the battle status
    data = %{
      cmd: "c.lobby.update_status",
      player: true,
      sync: 1,
      team_number: 0,
      ally_team_number: 0,
      side: 0,
      team_colour: 0
    }
    _tachyon_send(socket2, data)

    # Expect Coordinator mode announcement
    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => "Coordinator mode enabled",
      "sender" => user.id
    }

    # Expect welcome message
    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => " #{user2.name}: ####################",
      "sender" => Coordinator.get_coordinator_userid()
    }

    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => " #{user2.name}: This is the welcome message",
      "sender" => Coordinator.get_coordinator_userid()
    }

    reply = _tachyon_recv(socket2)
    assert reply == %{
      "cmd" => "s.lobby.announce",
      "message" => " #{user2.name}: ####################",
      "sender" => Coordinator.get_coordinator_userid()
    }
  end

  test "blacklist" do

  end

  test "whitelist" do

  end
end
