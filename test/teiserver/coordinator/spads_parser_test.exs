defmodule Teiserver.Coordinator.SpadsParserTest do
  alias Teiserver.Coordinator.SpadsParser
  use Teiserver.DataCase, async: true
  import Teiserver.TeiserverTestLib, only: [new_user: 0]

  describe "parsing teamSize information" do
    test "parses a single-digit value" do
      result = SpadsParser.handle_in("Global setting changed by marseel (teamSize=3)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamsize == 3
    end

    test "parses a two-digit value" do
      result = SpadsParser.handle_in("Global setting changed by marseel (teamSize=10)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamsize == 10
    end

    test "parses a two-digit value with repeated digits" do
      result = SpadsParser.handle_in("Global setting changed by marseel (teamSize=11)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamsize == 11
    end
  end

  describe "parsing nbTeams information" do
    test "parses a single-digit value" do
      result = SpadsParser.handle_in("Global setting changed by marseel (nbTeams=3)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamcount == 3
    end

    test "parses a two-digit value" do
      result = SpadsParser.handle_in("Global setting changed by marseel (nbTeams=10)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamcount == 10
    end

    test "parses a two-digit value with repeated digits" do
      result = SpadsParser.handle_in("Global setting changed by marseel (nbTeams=11)", %{})
      {:host_update, host_data} = result
      assert host_data.host_teamcount == 11
    end
  end

  test "parsing adding bosses" do
    user1 = new_user()
    user2 = new_user()

    result = SpadsParser.handle_in("Boss mode enabled for #{user1.name}", %{host_bosses: []})
    {:host_update, host_data} = result
    assert host_data.host_bosses == [user1.id]

    # Add a 2nd boss
    result =
      SpadsParser.handle_in("Boss mode enabled for #{user2.name}", %{host_bosses: [user1.id]})

    {:host_update, host_data} = result
    assert host_data.host_bosses == [user2.id, user1.id]

    # Remove bosses
    result =
      SpadsParser.handle_in("Boss mode disabled by #{user2.name}", %{host_bosses: [user1.id]})

    {:host_update, host_data} = result
    assert host_data.host_bosses == []
  end
end
