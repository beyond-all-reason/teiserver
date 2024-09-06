defmodule Teiserver.Matchmaking.QueueSyncTest do
  use Teiserver.DataCase
  alias Teiserver.Matchmaking

  test "default queue starts" do
    assert is_pid(Matchmaking.lookup_queue("1v1"))
  end

  test "list default queues" do
    assert [{"1v1", _}] = Matchmaking.list_queues()
  end
end
