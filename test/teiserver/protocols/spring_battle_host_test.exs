defmodule Teiserver.SpringBattleHostTest do
  use Central.ServerCase, async: false
  require Logger
  # alias Teiserver.BitParse
  # alias Teiserver.User
  alias Teiserver.Battle
  alias Teiserver.Protocols.Spring
  # alias Teiserver.Protocols.{SpringIn, SpringOut, Spring}
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TestLib,
    only: [auth_setup: 0, auth_setup: 1, _send: 2, _recv: 1, _recv_until: 1, new_user: 0]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "battle commands when not in a battle", %{socket: socket} do
    _send(socket, "LEAVEBATTLE\n")
    reply = _recv(socket)
    assert reply == :timeout

    _send(socket, "MYBATTLESTATUS 123 123\n")
    reply = _recv(socket)
    assert reply == :timeout
  end

  test "host battle test", %{socket: socket, user: user} do
    _send(
      socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tbattle_host_test\tgameTitle\tgameName\n"
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

    battle_id =
      join
      |> String.replace("JOINBATTLE ", "")
      |> String.replace(" gameHash", "")
      |> int_parse

    assert battle_status == "REQUESTBATTLESTATUS"

    # Check the battle actually got created
    battle = Battle.get_battle(battle_id)
    assert battle != nil
    assert Enum.count(battle.players) == 0

    # Now create a user to join the battle
    user2 = new_user()
    %{socket: socket2} = auth_setup(user2)
    _send(socket2, "JOINBATTLE #{battle_id} empty gameHash\n")
    # The response to joining a battle is tested elsewhere, we just care about the host right now
    _ = _recv(socket2)
    _ = _recv(socket2)

    reply = _recv_until(socket)
    assert reply =~ "ADDUSER #{user2.name} ?? 0 #{user2.id} LuaLobby Chobby\n"
    assert reply =~ "JOINEDBATTLE #{battle_id} #{user2.name}\n"
    assert reply =~ "CLIENTSTATUS #{user2.name} 0\n"

    # Kick user2
    battle = Battle.get_battle(battle_id)
    assert Enum.count(battle.players) == 1

    _send(socket, "KICKFROMBATTLE #{user2.name}\n")
    reply = _recv(socket2)
    assert reply == "FORCEQUITBATTLE\nLEFTBATTLE #{battle_id} #{user2.name}\n"

    # Add user 3
    user3 = new_user()
    %{socket: socket3} = auth_setup(user3)

    _send(socket2, "JOINBATTLE #{battle_id} empty gameHash\n")
    _ = _recv(socket2)

    # User 3 join the battle
    _send(socket3, "JOINBATTLE #{battle_id} empty gameHash\n")
    reply = _recv(socket2)
    assert reply == "JOINEDBATTLE #{battle_id} #{user3.name}\n"

    # Had a bug where the battle would be incorrectly closed
    # after kicking a player, it was caused by the host disconnecting
    # and in the process closed out the battle
    battle = Battle.get_battle(battle_id)
    assert battle != nil

    # Adding start rectangles
    assert Enum.count(battle.start_rectangles) == 0
    _send(socket, "ADDSTARTRECT 2 50 50 100 100\n")
    _ = _recv(socket)

    battle = Battle.get_battle(battle_id)
    assert Enum.count(battle.start_rectangles) == 1

    _send(socket, "REMOVESTARTRECT 2\n")
    _ = _recv(socket)
    battle = Battle.get_battle(battle_id)
    assert Enum.count(battle.start_rectangles) == 0

    # Add and remove script tags
    refute Map.has_key?(battle.tags, "custom/key1")
    refute Map.has_key?(battle.tags, "custom/key2")
    _send(socket, "SETSCRIPTTAGS custom/key1=customValue\tcustom/key2=customValue2\n")
    reply = _recv(socket)

    assert reply == "SETSCRIPTTAGS custom/key1=customValue\tcustom/key2=customValue2\n"

    battle = Battle.get_battle(battle_id)
    assert Map.has_key?(battle.tags, "custom/key1")
    assert Map.has_key?(battle.tags, "custom/key2")

    _send(socket, "REMOVESCRIPTTAGS custom/key1\tcustom/key3\n")
    reply = _recv(socket)
    assert reply == "REMOVESCRIPTTAGS custom/key1\tcustom/key3\n"

    battle = Battle.get_battle(battle_id)
    refute Map.has_key?(battle.tags, "custom/key1")
    # We never removed key2, it should still be there
    assert Map.has_key?(battle.tags, "custom/key2")

    # Enable and disable units
    _send(socket, "DISABLEUNITS unit1 unit2 unit3\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "DISABLEUNITS unit1 unit2 unit3\n"

    _send(socket, "ENABLEUNITS unit3\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "ENABLEUNITS unit3\n"

    _send(socket, "ENABLEALLUNITS\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "ENABLEALLUNITS\n"

    # Now kick both 2 and 3
    _send(socket, "KICKFROMBATTLE #{user2.name}\n")
    _send(socket, "KICKFROMBATTLE #{user3.name}\n")
    _ = _recv(socket2)
    _ = _recv(socket3)

    # Mybattle status
    # Clear out a bunch of things we've tested for socket1
    _ = _recv(socket2)
    _send(socket2, "MYBATTLESTATUS 4195330 600\n")
    :timer.sleep(100)
    _ = _recv(socket)
    reply = _recv(socket2)
    # socket2 got kicked, they shouldn't get any result from this
    assert reply == :timeout

    # Now lets get them to rejoin the battle
    _send(socket2, "JOINBATTLE #{battle_id} empty gameHash\n")
    :timer.sleep(100)
    _ = _recv(socket2)

    # Now try the status again
    _send(socket2, "MYBATTLESTATUS 4195330 600\n")
    :timer.sleep(100)
    _ = _recv(socket)
    reply = _recv(socket2)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195330 600\n"

    status = Spring.parse_battle_status("4195330")

    assert status == %{
             ready: true,
             handicap: 0,
             team_number: 0,
             ally_team_number: 0,
             player: true,
             sync: 1,
             side: 0
           }

    # Handicap
    _send(socket, "HANDICAP #{user2.name} 87\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4373506 600\n"
    status = Spring.parse_battle_status("4373506")
    assert status.handicap == 87

    _send(socket, "HANDICAP #{user2.name} 0\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195330 600\n"
    status = Spring.parse_battle_status("4195330")
    assert status.handicap == 0

    # Forceteamno
    _send(socket, "FORCETEAMNO #{user2.name} 1\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195334 600\n"
    status = Spring.parse_battle_status("4195334")
    assert status.team_number == 1

    # Forceallyno
    _send(socket, "FORCEALLYNO #{user2.name} 1\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195398 600\n"
    status = Spring.parse_battle_status("4195398")
    assert status.ally_team_number == 1

    # Forceteamcolour
    _send(socket, "FORCETEAMCOLOR #{user2.name} 800\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4195398 800\n"

    # Forcespectator
    _send(socket, "FORCESPECTATORMODE #{user2.name}\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "CLIENTBATTLESTATUS #{user2.name} 4194374 800\n"
    status = Spring.parse_battle_status("4194374")
    assert status.player == false

    # SAYBATTLEEX
    _send(socket, "SAYBATTLEEX This is me saying something from somewhere else\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "SAIDBATTLEEX #{user.name} This is me saying something from somewhere else\n"

    # UPDATEBATTLEINFO
    _send(socket, "UPDATEBATTLEINFO 1 0 123456 Map name here\n")
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "UPDATEBATTLEINFO #{battle.id} 1 0 123456 Map name here\n"

    # BOT TIME
    _send(socket, "ADDBOT bot1 4195330 0 ai_dll\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    [_, botid] = Regex.run(~r/ADDBOT (\d+) bot1 #{user.name} 4195330 0 ai_dll/, reply)
    botid = int_parse(botid)
    assert reply =~ "ADDBOT #{botid} bot1 #{user.name} 4195330 0 ai_dll\n"

    _send(socket, "UPDATEBOT bot1 4195394 2\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "UPDATEBOT #{botid} bot1 4195394 2\n"

    _send(socket, "REMOVEBOT bot1\n")
    # Gives time for pubsub to send out
    :timer.sleep(100)
    reply = _recv_until(socket)
    assert reply == "REMOVEBOT #{botid} bot1\n"

    # Leave the battle
    _send(socket, "LEAVEBATTLE\n")
    reply = _recv(socket)
    # assert reply =~ "LEFTBATTLE #{battle_id} #{user.name}\n"
    assert reply =~ "BATTLECLOSED #{battle_id}\n"

    _send(socket, "EXIT\n")
    _recv(socket)

    _send(socket2, "EXIT\n")
    _recv(socket2)

    _send(socket3, "EXIT\n")
    _recv(socket3)
  end
end
