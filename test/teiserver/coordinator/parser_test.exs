defmodule Teiserver.Coordinator.CoordinatorParserTest do
  alias Teiserver.Coordinator.Parser
  use Teiserver.DataCase, async: true

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

  describe "parsing commands typed in capital letters" do
    test "an all-caps command still works" do
      cmd = Parser.parse_command(1, "$STATUS")
      assert cmd.command == "status"
    end

    test "a capitalized command still works" do
      cmd = Parser.parse_command(1, "$Roll 2d6")
      assert cmd.command == "roll"
      assert cmd.remaining == "2d6"
    end

    test "the argument keeps its original letters" do
      cmd = Parser.parse_command(1, "$Rename VeryAwesomeLobbyName")
      assert cmd.command == "rename"
      assert cmd.remaining == "VeryAwesomeLobbyName"
    end
  end
end
