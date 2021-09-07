defmodule Teiserver.Protocols.Coordinator.SetupTest do
  use Central.ServerCase, async: false
  alias Teiserver.{Client}
  alias Teiserver.Account.UserCache
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Battle.Lobby
  alias Teiserver.Common.PubsubListener

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_recv: 1]

  @sleep 50

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()
    {:ok, socket: socket, user: user, pid: pid}
  end

  test "start, stop", %{user: user} do
    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    UserCache.update_user(%{user | moderator: true})
    Client.refresh_client(user.id)

    battle = TeiserverTestLib.make_battle(%{
      founder_id: user.id,
      founder_name: user.name
    })
    id = battle.id
    assert battle.coordinator_mode == false
    assert ConCache.get(:teiserver_consul_pids, battle.id) != nil

    # Start it up!
    Lobby.say(user.id, "!coordinator start", id)
    :timer.sleep(@sleep)

    battle = Lobby.get_battle!(id)
    assert battle.coordinator_mode == true

    # Stop it
    Lobby.say(user.id, "!force coordinator stop", id)
    :timer.sleep(@sleep)

    battle = Lobby.get_battle!(id)
    assert battle.coordinator_mode == false
  end

  test "test command vs no command", %{user: user, socket: socket} do
    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    UserCache.update_user(%{user | moderator: true})
    Client.refresh_client(user.id)

    battle = TeiserverTestLib.make_battle(%{
      founder_id: user.id,
      founder_name: user.name
    })
    assert battle.coordinator_mode == false

    Lobby.start_coordinator_mode(battle.id)
    battle = Lobby.get_battle!(battle.id)

    assert battle.coordinator_mode == true
    listener = PubsubListener.new_listener(["legacy_battle_updates:#{battle.id}"])

    # No command
    result = Lobby.say(user.id, "Test message", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {user.id, "Test message", battle.id}, :say}]

    # Now command
    result = Lobby.say(user.id, "!force forcestart", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    reply = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.communication.direct_message", "message" => "!forcestart", "sender" => user.id}

    # Converted message should appear here
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {user.id, "! force forcestart", battle.id}, :say}]
  end
end
