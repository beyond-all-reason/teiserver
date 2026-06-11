defmodule Teiserver.Battle.MatchMonitorTest do
  alias Teiserver.Battle
  alias Teiserver.Battle.MatchMonitorServer
  alias Teiserver.Support.Polling
  use Teiserver.ServerCase, async: false

  setup do
    Battle.start_match_monitor()

    on_exit(fn ->
      pid = MatchMonitorServer.get_match_monitor_pid()

      if pid do
        DynamicSupervisor.terminate_child(Teiserver.Coordinator.DynamicSupervisor, pid)
      end
    end)

    {:ok, %{}}
  end

  test "does not crash when lobby is unavailable" do
    # This test verifies that MatchMonitorServer doesn't crash when
    # trying to start a match for a non-existent lobby

    # Get the MatchMonitorServer PID
    monitor_pid = MatchMonitorServer.get_match_monitor_pid()
    assert is_pid(monitor_pid)

    # Send a launch message for a non-existent lobby
    send(monitor_pid, {:new_message, 99_999, "autohosts", "* Launching game..."})

    # Verify the server is still running (hasn't crashed)
    Polling.poll_until(
      fn ->
        Process.alive?(monitor_pid)
      end,
      fn alive -> alive == true end
    )

    # Verify the server is still registered
    assert MatchMonitorServer.get_match_monitor_pid() == monitor_pid
  end
end
