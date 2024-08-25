defmodule Teiserver.Matchmaking.QueueSynest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.QueueServer

  setup _context do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    id = UUID.uuid4()

    {:ok, pid} =
      QueueServer.init_state(%{id: id, name: id, team_size: 1, team_count: 2})
      |> QueueServer.start_link()

    {:ok, user: user, queue_id: id, queue_pid: pid}
  end

  describe "joining" do
    test "works", %{user: user, queue_id: queue_id} do
      assert :ok = Matchmaking.join_queue(queue_id, user.id)

      assert {:error, :already_queued} == Matchmaking.join_queue(queue_id, user.id)
    end

    test "invalid queue", %{user: user} do
      assert {:error, :invalid_queue} == Matchmaking.join_queue("INVALID!!", user.id)
    end
  end
end
