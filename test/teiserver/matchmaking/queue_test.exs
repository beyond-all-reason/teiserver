defmodule Teiserver.Matchmaking.QueueTest do

  use Teiserver.DataCase
  alias Teiserver.Matchmaking

  test "default queue starts" do
    assert is_pid(Matchmaking.lookup_queue("1v1"))
  end

end
