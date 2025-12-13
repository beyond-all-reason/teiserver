defmodule Teiserver.SpringBattleHostTest do
  use Teiserver.ServerCase, async: false
  require Logger
  alias Teiserver.{Coordinator, Battle, Lobby}
  alias Teiserver.Protocols.Spring
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  import Teiserver.TeiserverTestLib,
    only: [auth_setup: 0, _send_raw: 2, _recv_raw: 1, _recv_until: 1]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "battle commands when not in a battle", %{socket: socket} do
    _send_raw(socket, "LEAVEBATTLE\n")
    reply = _recv_raw(socket)
    assert reply == :timeout

    _send_raw(socket, "MYBATTLESTATUS 123 123\n")
    reply = _recv_raw(socket)
    assert reply == :timeout
  end

  @tag :needs_attention
  test "battle with password", %{socket: socket, user: user} do
    _send_raw(
      socket,
      "OPENBATTLE 0 0 password_test 322 16 gameHash 0 mapHash engineName\tengineVersion\tlobby_host_test\tgameTitle\tgameName\n"
    )

    # Find battle
    battle =
      Lobby.list_lobbies()
      |> Enum.filter(fn b -> b.founder_id == user.id end)
      |> hd()

    assert battle.password == "password_test"
  end

  @tag :needs_attention
  test "!rehost bug test", %{socket: host_socket, user: host_user} do
    %{socket: watcher_socket} = auth_setup()
    %{socket: p1_socket, user: p1_user} = auth_setup()
    %{socket: p2_socket, user: p2_user} = auth_setup()

    # Open battle
    _send_raw(
      host_socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tlobby_host_test\tgameTitle\tgameName\n"
    )

    # Find battle ID
    lobby_id =
      Lobby.list_lobbies()
      |> Enum.filter(fn b -> b.founder_id == host_user.id end)
      |> hd()
      |> Map.get(:id)

    # Clear watcher
    _ = _recv_until(watcher_socket)

    # Join
    _send_raw(p1_socket, "JOINBATTLE #{lobby_id} empty script_password2\n")
    _send_raw(p2_socket, "JOINBATTLE #{lobby_id} empty script_password2\n")

    # Nobody has been accepted yet, should not see anything
    reply = _recv_raw(watcher_socket)
    assert reply == :timeout

    # Now accept
    _send_raw(host_socket, "JOINBATTLEACCEPT #{p1_user.name}\n")
    _send_raw(host_socket, "JOINBATTLEACCEPT #{p2_user.name}\n")

    # Accept has happened, should see stuff
    reply = _recv_raw(watcher_socket)

    assert reply ==
             "JOINEDBATTLE #{lobby_id} #{p1_user.name}\nJOINEDBATTLE #{lobby_id} #{p2_user.name}\n"

    # Now have the host leave
    _send_raw(host_socket, "LEAVEBATTLE\n")
    :timer.sleep(500)

    reply = _recv_until(watcher_socket)
    assert reply == "BATTLECLOSED #{lobby_id}\n"
  end

  @tag :needs_attention
  test "host battle test", %{socket: socket, user: user} do
    _send_raw(
      socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tlobby_host_test\tgameTitle\tgameName\n"
    )

    reply =
      _recv_until(socket)
      |> String.split("\n")

    [
      opened,
      open,
      join,
      _tags,
      battle_status,
      _battle_opened
      | _
    ] = reply

    assert opened =~ "BATTLEOPENED "
    assert open =~ "OPENBATTLE "
    assert join =~ "JOINBATTLE "
    assert join =~ " gameHash"

    lobby_id =
      join
      |> String.replace("JOINBATTLE ", "")
      |> String.replace(" gameHash", "")
      |> int_parse()

    assert battle_status == "REQUESTBATTLESTATUS"

    # Check the battle actually got created
    battle = Lobby.get_lobby(lobby_id)
    assert battle != nil
    assert Enum.empty?(battle.players)

    # Now create a user to join the battle
    %{socket: socket2, user: user2} = auth_setup()

    # Check user1 hears about this
    reply = _recv_raw(socket)
    assert reply =~ "ADDUSER #{user2.name} ?? #{user2.id} LuaLobby Chobby\n"

    # Attempt to join
    _send_raw(socket2, "JOINBATTLE #{lobby_id} empty script_password2\n")

    # Rejecting a join request is covered elsewhere, we will just handle accepting it for now
    reply = _recv_raw(socket)
    assert reply == "JOINBATTLEREQUEST #{user2.name} 127.0.0.1\n"

    # Send acceptance
    _send_raw(socket, "JOINBATTLEACCEPT #{user2.name}\n")

    # The response to joining a battle is tested elsewhere, we just care about the host right now
    _ = _recv_raw(socket2)
    _ = _recv_raw(socket2)

    reply = _recv_until(socket)
    assert reply =~ "JOINEDBATTLE #{lobby_id} #{user2.name} script_password2\n"

    # This used to get updated, why not any more?
    # assert reply =~ "CLIENTSTATUS #{user2.name} 0\n"

    # Kick user2
    battle = Lobby.get_lobby(lobby_id)
    assert Enum.count(battle.players) == 1

    _send_raw(socket, "KICKFROMBATTLE #{user2.name}\n")
    reply = _recv_raw(socket2)
    assert reply =~ "FORCEQUITBATTLE\nLEFTBATTLE #{lobby_id} #{user2.name}\n"

    # Add user 3
    %{socket: socket3, user: user3} = auth_setup()

    _send_raw(socket2, "JOINBATTLE #{lobby_id} empty script_password3\n")
    _send_raw(socket, "JOINBATTLEACCEPT #{user2.name}\n")
    _ = _recv_raw(socket)
    _ = _recv_raw(socket2)

    # User 3 join the battle
    _send_raw(socket3, "JOINBATTLE #{lobby_id} empty script_password3\n")
    _send_raw(socket, "JOINBATTLEACCEPT #{user3.name}\n")
    reply = _recv_raw(socket2)
    assert reply == "JOINEDBATTLE #{lobby_id} #{user3.name}\n"

    # Had a bug where the battle would be incorrectly closed
    # after kicking a player, it was caused by the host disconnecting
    # and in the process closed out the battle
    battle = Lobby.get_lobby(lobby_id)
    assert battle != nil

    # Adding start rectangles
    assert Enum.empty?(battle.start_areas)
    _send_raw(socket, "ADDSTARTRECT 2 50 50 100 100\n")
    _ = _recv_raw(socket)

    battle = Lobby.get_lobby(lobby_id)
    assert Enum.count(battle.start_areas) == 1

    _send_raw(socket, "REMOVESTARTRECT 2\n")
    _ = _recv_raw(socket)
    battle = Lobby.get_lobby(lobby_id)
    assert Enum.empty?(battle.start_areas)

    # Add and remove script tags
    modoptions = Battle.get_modoptions(lobby_id)
    refute Map.has_key?(modoptions, "custom/key1")
    refute Map.has_key?(modoptions, "custom/key2")
    _send_raw(socket, "SETSCRIPTTAGS custom/key1=customValue\tcustom/key2=customValue2\n")
    reply = _recv_raw(socket)

    assert reply == "SETSCRIPTTAGS custom/key1=customValue\tcustom/key2=customValue2\n"

    modoptions = Battle.get_modoptions(lobby_id)
    assert Map.has_key?(modoptions, "custom/key1")
    assert Map.has_key?(modoptions, "custom/key2")

    _send_raw(socket, "REMOVESCRIPTTAGS custom/key1 custom/key3\n")
    reply = _recv_raw(socket)
    assert reply == "REMOVESCRIPTTAGS custom/key1\n"

    modoptions = Battle.get_modoptions(lobby_id)
    refute Map.has_key?(modoptions, "custom/key1")
    # We never removed key2, it should still be there
    assert Map.has_key?(modoptions, "custom/key2")

    # Enable and disable units
    _send_raw(socket, "DISABLEUNITS unit1 unit2 unit3\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "DISABLEUNITS unit1 unit2 unit3\n"

    _send_raw(socket, "ENABLEUNITS unit3\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "ENABLEUNITS unit3\n"

    _send_raw(socket, "ENABLEALLUNITS\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "ENABLEALLUNITS\n"

    # Now kick both 2 and 3
    _send_raw(socket, "KICKFROMBATTLE #{user2.name}\n")
    _send_raw(socket, "KICKFROMBATTLE #{user3.name}\n")
    _ = _recv_raw(socket2)
    _ = _recv_raw(socket3)

    # Mybattle status
    # Clear out a bunch of things we've tested for socket1
    _ = _recv_raw(socket2)
    _send_raw(socket2, "MYBATTLESTATUS 4195330 600\n")
    :timer.sleep(100)
    _ = _recv_raw(socket)
    reply = _recv_raw(socket2)
    # socket2 got kicked, they shouldn't get any result from this
    assert reply == :timeout

    # Now lets get them to rejoin the battle
    _send_raw(socket2, "JOINBATTLE #{lobby_id} empty script_password2\n")
    _send_raw(socket, "JOINBATTLEACCEPT #{user2.name}\n")
    :timer.sleep(100)
    _ = _recv_raw(socket2)

    # Now try the status again
    _send_raw(socket2, "MYBATTLESTATUS 4195330 600\n")
    :timer.sleep(100)
    _ = _recv_raw(socket)
    reply = _recv_raw(socket2)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195328 600\n"

    status = Spring.parse_battle_status("4195330")

    assert status == %{
             ready: true,
             handicap: 0,
             player_number: 0,
             team_number: 0,
             player: true,
             sync: %{engine: 1, game: 1, map: 1},
             side: 0
           }

    status = Spring.parse_battle_status("4195328")

    assert status == %{
             ready: false,
             handicap: 0,
             player_number: 0,
             team_number: 0,
             player: true,
             sync: %{engine: 1, game: 1, map: 1},
             side: 0
           }

    # Handicap
    _send_raw(socket, "HANDICAP #{user2.name} 87\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4373504 600\n"
    status = Spring.parse_battle_status("4373506")
    assert status.handicap == 87

    _send_raw(socket, "HANDICAP #{user2.name} 0\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195328 600\n"
    status = Spring.parse_battle_status("4195330")
    assert status.handicap == 0

    # Forceteamno
    _send_raw(socket, "FORCETEAMNO #{user2.name} 1\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195332 600\n"
    status = Spring.parse_battle_status("4195332")
    assert status.player_number == 1

    # Forceallyno
    _send_raw(socket, "FORCEALLYNO #{user2.name} 1\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195396 600\n"
    status = Spring.parse_battle_status("4195398")
    assert status.team_number == 1

    # Forceteamcolour
    _send_raw(socket, "FORCETEAMCOLOR #{user2.name} 800\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195396 800\n"

    # Forcespectator
    _send_raw(socket, "FORCESPECTATORMODE #{user2.name}\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4194372 800\n"
    status = Spring.parse_battle_status("4194374")
    assert status.player == false

    # SAYBATTLEEX
    _send_raw(socket, "SAYBATTLEEX This is me saying something from somewhere else\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "SAIDBATTLEEX #{user.name} This is me saying something from somewhere else\n"

    # UPDATEBATTLEINFO
    _send_raw(socket, "UPDATEBATTLEINFO 0 0 123456 Map name here\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "UPDATEBATTLEINFO #{battle.id} 0 0 123456 Map name here\n"

    # BOT TIME
    _send_raw(socket, "ADDBOT bot1 4195330 0 ai_dll\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    [_, botid] = Regex.run(~r/ADDBOT (\d+) bot1 #{user.name} 4195330 0 ai_dll/, reply)
    botid = int_parse(botid)
    assert reply =~ "ADDBOT #{botid} bot1 #{user.name} 4195330 0 ai_dll\n"

    _send_raw(socket, "UPDATEBOT bot1 4195394 2\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "UPDATEBOT #{botid} bot1 4195394 2\n"

    # Test out non-hosts updating the bot
    _recv_until(socket2)
    _send_raw(socket2, "UPDATEBOT bot1 4195394 2\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket2)
    assert reply == ""

    _send_raw(socket2, "REMOVEBOT bot1\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket2)
    assert reply == ""

    # Now back to actually doing stuff
    _send_raw(socket, "REMOVEBOT bot1\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "REMOVEBOT #{botid} bot1\n"

    # Rename the battle, should get a message about the rename very shortly afterwards
    _send_raw(socket, "c.battle.update_lobby_title NewName 123\n")
    :timer.sleep(1000)
    reply = _recv_until(socket)

    assert reply =~
             "OK cmd=c.battle.update_lobby_title\ns.battle.update_lobby_title #{lobby_id}\tNewName 123\n"

    # Update the host settings
    state = Coordinator.call_consul(lobby_id, :get_all)
    assert state.host_teamcount == 2
    assert state.host_teamsize == 8
    _send_raw(socket, "c.battle.update_host {\"teamSize\": \"8\", \"nbTeams\": \"5\"}\n")
    :timer.sleep(100)
    reply = _recv_raw(socket)
    assert reply == :timeout
    state = Coordinator.call_consul(lobby_id, :get_all)
    assert state.host_teamcount == 5
    assert state.host_teamsize == 8

    # Leave the battle
    _send_raw(socket, "LEAVEBATTLE\n")
    reply = _recv_raw(socket)
    # assert reply =~ "LEFTBATTLE #{lobby_id} #{user.name}\n"
    assert reply =~ "BATTLECLOSED #{lobby_id}\n"

    _send_raw(socket, "EXIT\n")
    _recv_raw(socket)

    _send_raw(socket2, "EXIT\n")
    _recv_raw(socket2)

    _send_raw(socket3, "EXIT\n")
    _recv_raw(socket3)
  end
end
