defmodule Teiserver.Matchmaking.QueueSyncTest do
  use Teiserver.DataCase
  alias Teiserver.Matchmaking

  setup do
    ExUnit.Callbacks.start_supervised!(Teiserver.Tachyon.System)
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
