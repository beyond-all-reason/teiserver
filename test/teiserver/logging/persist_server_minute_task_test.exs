defmodule Teiserver.Logging.Tasks.PersistServerMinuteTaskTest do
  use Central.DataCase
  alias Teiserver.{Logging}
  alias Teiserver.Logging.Tasks.PersistServerMinuteTask

  test "perform task" do
    # Run the task
    assert :ok == PersistServerMinuteTask.perform(%{})
    now = Timex.now() |> Timex.set(microsecond: 0)

    # Now ensure it ran
    log = Logging.get_server_minute_log(now)

    assert Map.has_key?(log.data, "battle")
    assert Map.has_key?(log.data, "client")
    assert Map.has_key?(log.data, "matchmaking")
  end
end
