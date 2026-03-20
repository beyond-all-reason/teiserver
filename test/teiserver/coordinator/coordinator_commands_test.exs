defmodule Teiserver.Coordinator.CoordinatorCommandsTest do
  alias Teiserver.Coordinator.CoordinatorCommands

  use ExUnit.Case, async: true

  test "is_coordinator_command/1 returns true for help and whoami" do
    assert true == CoordinatorCommands.coordinator_command?("help")

    assert true == CoordinatorCommands.coordinator_command?("whoami")
  end

  test "is_coordinator_command/1 returns true for modparty and unparty" do
    assert true == CoordinatorCommands.coordinator_command?("modparty")

    assert true == CoordinatorCommands.coordinator_command?("unparty")
  end

  test "is_coordinator_command/1 returns false for status and broadcast" do
    assert false == CoordinatorCommands.coordinator_command?("status")

    assert false == CoordinatorCommands.coordinator_command?("broadcast")
  end
end
