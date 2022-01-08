defmodule Teiserver.Coordinator.SpadsParserTest do
  use Central.DataCase, async: true
  alias Teiserver.Coordinator.SpadsParser

  test "parsing teamSize information" do
    result = SpadsParser.handle_in("Global setting changed by marseel (teamSize=5)")
    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_teamsize == 5
  end

  test "parsing nbTeams information" do
    result = SpadsParser.handle_in("Global setting changed by marseel (nbTeams=3)")
    assert result != nil
    {:host_update, host_data} = result
    assert host_data.host_teamcount == 3
  end
end
