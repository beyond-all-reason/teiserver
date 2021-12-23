defmodule Teiserver.Coordinator.CoordinatorCommands do
  def handle_command(%{command: "whoami"} = cmd, state) do
    handle_command(Map.put(cmd, :command, "status"), state)
  end
end
