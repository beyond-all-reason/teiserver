defmodule Teiserver.Battle.MatchMonitorStartupTest do
  alias Teiserver.Battle.MatchMonitorServer
  alias Teiserver.Support.Polling
  use Teiserver.ServerCase, async: false

  @cache :application_metadata_cache
  @ready "teiserver_full_startup_completed"

  test "can shut down while waiting for startup and finish login on a later retry" do
    previous = Teiserver.cache_get(@cache, @ready)

    on_exit(fn ->
      if is_nil(previous) do
        Teiserver.cache_delete(@cache, @ready)
      else
        Teiserver.cache_put(@cache, @ready, previous)
      end
    end)

    Teiserver.cache_put(@cache, @ready, false)
    pending = start_supervised!(MatchMonitorServer)
    ref = Process.monitor(pending)
    assert :sys.get_state(pending) == %{}
    stop_supervised!(MatchMonitorServer)
    assert_receive {:DOWN, ^ref, :process, ^pending, :shutdown}

    retrying = start_supervised!(MatchMonitorServer)
    assert :sys.get_state(retrying) == %{}
    Teiserver.cache_put(@cache, @ready, true)

    assert %{userid: user_id} =
             Polling.poll_until(
               fn -> :sys.get_state(retrying) end,
               &Map.has_key?(&1, :userid),
               wait: 20,
               limit: 150
             )

    assert user_id == MatchMonitorServer.get_match_monitor_userid()
    stop_supervised!(MatchMonitorServer)
  end
end
