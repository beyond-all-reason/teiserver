defmodule Teiserver.Logging.Tasks.PersistServerMinuteTaskTest do
  alias Teiserver.Logging
  alias Teiserver.Logging.Tasks.PersistServerMinuteTask
  use Teiserver.DataCase

  # https://github.com/beyond-all-reason/teiserver/actions/runs/26998159837/job/79672243657?pr=1237
  @tag :needs_attention
  test "perform task" do
    # Run the task
    assert :ok == PersistServerMinuteTask.perform(%{})
    now = %{DateTime.utc_now() | microsecond: {0, 0}}

    # Now ensure it ran
    log = Logging.get_server_minute_log(now)

    assert Map.has_key?(log.data, "battle")
    assert Map.has_key?(log.data, "client")
    assert Map.has_key?(log.data, "matchmaking")
  end
end
