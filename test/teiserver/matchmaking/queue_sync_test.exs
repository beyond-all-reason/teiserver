defmodule Teiserver.Matchmaking.QueueSyncTest do
  alias Teiserver.Matchmaking
  use Teiserver.DataCase

  @moduletag :tachyon

  test "default queue starts" do
    assert is_pid(Matchmaking.lookup_queue("1v1"))
  end

  test "list default queues" do
    queues = Matchmaking.list_queues() |> Enum.map(fn {id, _pid} -> id end) |> MapSet.new()
    assert queues == MapSet.new(["1v1", "2v2"])
  end
end
