defmodule Teiserver.Coordinator.CoordinatorCommandsTest do
  use ExUnit.Case, async: true

  alias Teiserver.Coordinator.CoordinatorCommands

  test "is_coordinator_command/1 returns true for help and whoami" do
    assert true == CoordinatorCommands.is_coordinator_command?("help")

    assert true == CoordinatorCommands.is_coordinator_command?("whoami")
  end

  test "is_coordinator_command/1 returns true for modparty and unparty" do
    assert true == CoordinatorCommands.is_coordinator_command?("modparty")

    assert true == CoordinatorCommands.is_coordinator_command?("unparty")
  end

  test "is_coordinator_command/1 returns false for status and broadcast" do
    assert false == CoordinatorCommands.is_coordinator_command?("status")

    assert false == CoordinatorCommands.is_coordinator_command?("broadcast")
  end
end
