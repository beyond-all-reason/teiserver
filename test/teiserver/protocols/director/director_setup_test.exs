defmodule Teiserver.Protocols.Director.SetupTest do
  use Central.ServerCase, async: false
  alias Teiserver.TeiserverTestLib
  alias Teiserver.Battle
  alias Teiserver.Common.PubsubListener

  @sleep 200

  setup do
    Teiserver.Director.start_director()
    # Sleep to allow the director to be started up each time
    :timer.sleep(100)
    :ok
  end

  test "start, stop" do
    battle = TeiserverTestLib.make_battle()
    id = battle.id
    assert battle.director_mode == false

    # Start it up!
    Battle.say(1, "!director start", id)
    :timer.sleep(@sleep)

    battle = Battle.get_battle!(id)
    assert battle.director_mode == true

    # TODO: Check the consul is created and assigned to this battle

    # Stop it
    Battle.say(123_456, "!director stop", id)
    :timer.sleep(@sleep)

    battle = Battle.get_battle!(id)
    assert battle.director_mode == false
  end

  test "create as director" do
    battle =
      TeiserverTestLib.make_battle(%{
        director_mode: true
      })

    assert battle.director_mode == true
  end

  test "test command vs no command" do
    battle =
      TeiserverTestLib.make_battle(%{
        director_mode: true
      })

    assert battle.director_mode == true
    listener = PubsubListener.new_listener(["battle_updates:#{battle.id}"])

    # No command
    result = Battle.say(123_456, "Test message", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == [{:battle_updated, battle.id, {123_456, "Test message", battle.id}, :say}]

    # Now command
    result = Battle.say(123_456, "!start", battle.id)
    assert result == :ok

    :timer.sleep(@sleep)
    messages = PubsubListener.get(listener)
    assert messages == []
  end
end
