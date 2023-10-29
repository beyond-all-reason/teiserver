defmodule Teiserver.Coordinator.CoordinatorParserTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Coordinator.Parser

  test "parsing commands" do
    cmd = Parser.parse_command(1, "$map map_name")
    assert cmd.silent == false
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"

    cmd = Parser.parse_command(1, "$%map map_name")
    assert cmd.silent == true
    assert cmd.command == "map"
    assert cmd.remaining == "map_name"
  end
end
