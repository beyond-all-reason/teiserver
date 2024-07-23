defmodule Teiserver.Coordinator.SpadsParserTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Coordinator.SpadsParser
  import Teiserver.TeiserverTestLib, only: [new_user: 0]

  test "parsing teamSize information" do
    result = SpadsParser.handle_in("Global setting changed by marseel (teamSize=5)", %{})
    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_teamsize == 5
  end

  test "parsing nbTeams information" do
    result = SpadsParser.handle_in("Global setting changed by marseel (nbTeams=3)", %{})
    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_teamcount == 3
  end

  test "parsing adding bosses" do
    user1 = new_user()
    user2 = new_user()

    result = SpadsParser.handle_in("Boss mode enabled for #{user1.name}", %{host_bosses: []})
    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_bosses == [user1.id]

    # Add a 2nd boss
    result =
      SpadsParser.handle_in("Boss mode enabled for #{user2.name}", %{host_bosses: [user1.id]})

    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_bosses == [user2.id, user1.id]

    # Remove bosses
    result =
      SpadsParser.handle_in("Boss mode disabled by #{user2.name}", %{host_bosses: [user1.id]})

    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_bosses == []
  end

  test "parsing changes to presets" do
    state = %{host_bosses: []}

    message =
      "* BarManager|{\"BattleStateChanged\": {\"locked\": \"unlocked\", \"autoBalance\": \"advanced\", \"teamSize\": \"6\", \"nbTeams\": \"2\", \"balanceMode\": \"clan;skill\", \"preset\": \"default\"}}"

    bar_manager_state = SpadsParser.parse_barmanager_state(message)
    assert bar_manager_state == {:ok, %{preset: "default"}}

    result = SpadsParser.handle_in(message, %{host_bosses: []})
    assert result == {:host_update, %{host_preset: "default"}}
  end

  test "bad string" do
    state = %{host_bosses: []}

    message = "blah"

    result = SpadsParser.handle_in(message, %{host_bosses: []})
    assert result == nil
  end
end
