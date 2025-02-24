defmodule Teiserver.Matchmaking.QueueTest do
  use Teiserver.DataCase
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.AssetFixtures

  defp stg_attr(id),
    do: %{
      spring_name: "Supreme that glitters",
      display_name: "Supreme That Glitters",
      thumbnail_url: "https://www.beyondallreason.info/map/?!",
      matchmaking_queues: [id]
    }

  setup _context do
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
    id = UUID.uuid4()

    AssetFixtures.create_map(stg_attr(id))

    {:ok, pid} =
      QueueServer.init_state(%{
        id: id,
        name: id,
        team_size: 1,
        team_count: 2,
        engines: ["spring", "recoil"],
        games: ["BAR test version", "BAR release version"]
      })
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

    test "party too big", %{user: user, queue_id: queue_id} do
      member = %{
        player_ids: [user.id, user.id],
        rating: %{},
        avoid: [],
        joined_at: DateTime.utc_now(),
        search_distance: 0,
        increase_distance_after: 10
      }

      assert {:error, :too_many_players} = Matchmaking.join_queue(queue_id, member)
    end

    test "paired user still in queue", %{user: user, queue_id: queue_id, queue_pid: queue_pid} do
      user2 = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
      assert :ok = Matchmaking.join_queue(queue_id, user.id)
      assert :ok = Matchmaking.join_queue(queue_id, user2.id)
      send(queue_pid, :tick)
      assert {:error, :already_queued} == Matchmaking.join_queue(queue_id, user.id)
    end
  end

  describe "leaving" do
    test "works", %{user: user, queue_id: queue_id} do
      assert {:error, :not_queued} = Matchmaking.leave_queue(queue_id, user.id)

      assert {:error, :invalid_queue} =
               Matchmaking.leave_queue("lolnope that't not a queue", user.id)

      :ok = Matchmaking.join_queue(queue_id, user.id)
      assert :ok = Matchmaking.leave_queue(queue_id, user.id)
    end
  end
end
