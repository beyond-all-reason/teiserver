defmodule Teiserver.Coordinator.CoordinatorCommandsTest do
  use ExUnit.Case

  test "is_coordinator_command/1 returns true for help and whoami" do
    assert true == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("help")

    assert true == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("whoami")
  end

  test "is_coordinator_command/1 returns true for modparty and unparty" do
    assert true == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("modparty")

    assert true == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("unparty")
  end

  test "is_coordinator_command/1 returns false for status and broadcast" do
    assert false == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("status")

    assert false == Teiserver.Coordinator.CoordinatorCommands.is_coordinator_command?("broadcast")
  end
end
