defmodule Teiserver.Coordinator.CoordinatorParserTest do
  use Central.DataCase, async: true
  alias Teiserver.Coordinator.Parser

  test "parsing commands" do
    cmd = Parser.parse_command(1, "!map map_name")
    assert cmd.vote == false
    assert cmd.force == false
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"

    cmd = Parser.parse_command(1, "!force map map_name")
    assert cmd.vote == false
    assert cmd.force == true
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"

    cmd = Parser.parse_command(1, "!cv map map_name")
    assert cmd.vote == true
    assert cmd.force == false
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"

    cmd = Parser.parse_command(1, "!vote map map_name")
    assert cmd.vote == true
    assert cmd.force == false
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"
  end
end
