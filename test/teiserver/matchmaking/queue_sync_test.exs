defmodule Teiserver.Matchmaking.QueueSyncTest do
  use Teiserver.DataCase
  alias Teiserver.Matchmaking

  @moduletag :tachyon

  setup(_) do
    Teiserver.Support.Polling.poll_until(&Teiserver.Matchmaking.list_queues/0, &(&1 != []))
    :ok
  end

  test "default queue starts" do
    assert is_pid(Matchmaking.lookup_queue("1v1"))
  end

  test "list default queues" do
    queues = Matchmaking.list_queues() |> Enum.map(fn {id, _} -> id end) |> MapSet.new()
    assert queues == MapSet.new(["1v1", "2v2"])
  end
end
