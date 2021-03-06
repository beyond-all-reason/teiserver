defmodule Teiserver.SpringBattleHostTest do
  use Central.ServerCase
  require Logger
  # alias Teiserver.BitParse
  # alias Teiserver.User
  alias Teiserver.Battle
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  import Teiserver.TestLib,
    only: [auth_setup: 0, auth_setup: 1, _send: 2, _recv: 1, _recv_until: 1, new_user: 0]

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  test "host battle test", %{socket: socket} do
    _send(
      socket,
      "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tmapName\tgameTitle\tgameName\n"
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
      _battle_opened,
      _joinedbattle,
      _clientstatus
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
    assert reply =~ "CLIENTSTATUS #{user2.name} 16\n"

    # Kick user2
    battle = Battle.get_battle(battle_id)
    assert Enum.count(battle.players) == 1

    _send(socket, "KICKFROMBATTLE #{user2.name}\n")
    reply = _recv(socket2)
    assert reply == "FORCEQUITBATTLE\nLEFTBATTLE #{battle_id} #{user2.name}\n"

    # Had a bug where the battle would be incorrectly closed
    # after kicking a player
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

    # Leave the battle

    _send(socket, "EXIT\n")
    _recv(socket)

    _send(socket2, "EXIT\n")
    _recv(socket2)
  end
end
