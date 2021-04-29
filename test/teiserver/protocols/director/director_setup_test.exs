defmodule Teiserver.Protocols.Director.SetupTest do
  use Central.ServerCase, async: false
  alias Teiserver.TestLib
  alias Teiserver.Battle
  alias Teiserver.Common.PubsubListener

  @sleep 200

  test "start, stop" do
    battle = TestLib.make_battle()
    id = battle.id
    assert battle.director_mode == false

    # Start it up!
    Battle.say(1, "!director start", id)

    battle = Battle.get_battle!(id)
    assert battle.director_mode == true

    # Stop it
    Battle.say(123456, "!director stop", id)

    battle = Battle.get_battle!(id)
    assert battle.director_mode == false
  end

  test "create as director" do
    battle = TestLib.make_battle(%{
      director_mode: true
    })
    assert battle.director_mode == true
  end

  test "test command vs no command" do
    battle = TestLib.make_battle(%{
      director_mode: true
    })
    assert battle.director_mode == true
    listener = PubsubListener.new_listener(["battle_updates:#{battle.id}"])

    # No command
    result = Battle.say(123456, "Test message", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {123456, "Test message", battle.id}, :say}]

    # Now command
    result = Battle.say(123456, "!start", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == []
  end
end
