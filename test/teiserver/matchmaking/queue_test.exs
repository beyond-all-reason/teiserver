defmodule Teiserver.Matchmaking.QueueTest do
  use Teiserver.DataCase
  alias Teiserver.Matchmaking
  alias Teiserver.Matchmaking.QueueServer
  alias Teiserver.AssetFixtures

  @moduletag :tachyon

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

    initial_state =
      QueueServer.init_state(%{
        id: id,
        name: id,
        team_size: 1,
        team_count: 2,
        engines: ["spring", "recoil"],
        games: ["BAR test version", "BAR release version"]
      })

    {:ok, pid} = QueueServer.start_link(initial_state)

    {:ok, user: user, queue_id: id, queue_pid: pid}
  end

  describe "joining" do
    test "works", %{user: user, queue_id: queue_id} do
      assert {:ok, _pid} = Matchmaking.join_queue(queue_id, user.id)

      assert {:error, :already_queued} == Matchmaking.join_queue(queue_id, user.id)
    end

    test "invalid queue", %{user: user} do
      assert {:error, :invalid_queue} == Matchmaking.join_queue("INVALID!!", user.id)
    end

    test "paired user still in queue", %{user: user, queue_id: queue_id, queue_pid: queue_pid} do
      user2 = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})
      assert {:ok, ^queue_pid} = Matchmaking.join_queue(queue_id, user.id)
      assert {:ok, ^queue_pid} = Matchmaking.join_queue(queue_id, user2.id)
      send(queue_pid, :tick)
      assert {:error, :already_queued} == Matchmaking.join_queue(queue_id, user.id)
    end
  end

  describe "leaving" do
    test "works", %{user: user, queue_id: queue_id} do
      assert {:error, :not_queued} = Matchmaking.leave_queue(queue_id, user.id)

      assert {:error, :invalid_queue} =
               Matchmaking.leave_queue("lolnope that't not a queue", user.id)

      {:ok, _pid} = Matchmaking.join_queue(queue_id, user.id)
      assert :ok = Matchmaking.leave_queue(queue_id, user.id)
    end
  end

  describe "queue statistics" do
    test "initial stats are zero", %{queue_id: queue_id} do
      # Initially stats should be zero
      {:ok, stats} = Matchmaking.get_stats(queue_id)

      assert stats == %{
               total_joined: 0,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 0
             }
    end

    test "tracks joins and leaves", %{user: user, queue_id: queue_id} do
      # Initially stats should be zero
      {:ok, stats} = Matchmaking.get_stats(queue_id)

      assert stats == %{
               total_joined: 0,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 0
             }

      # Join the queue
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user.id)
      {:ok, stats} = Matchmaking.get_stats(queue_id)

      assert stats == %{
               total_joined: 1,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 1
             }

      # Leave the queue
      :ok = Matchmaking.leave_queue(queue_id, user.id)
      {:ok, stats} = Matchmaking.get_stats(queue_id)

      assert stats == %{
               total_joined: 1,
               total_left: 1,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 0
             }
    end

    test "tracks party joins", %{queue_id: queue_id} do
      user1 = Central.Helpers.GeneralTestLib.make_user()
      party_id = UUID.uuid4()

      # Create a party with 1 player (valid for team_size: 1 queue)
      {:ok, _pid} = Matchmaking.party_join_queue(queue_id, party_id, [user1])
      {:ok, stats} = Matchmaking.get_stats(queue_id)
      # No stats updated yet, party is pending
      assert stats == %{
               total_joined: 0,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 0
             }

      # Now actually join the queue with the party
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user1.id, party_id)
      {:ok, stats} = Matchmaking.get_stats(queue_id)
      # Now the player has joined
      assert stats == %{
               total_joined: 1,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 1
             }
    end

    test "tracks wait time when matches are created", %{queue_id: queue_id} do
      user1 = Central.Helpers.GeneralTestLib.make_user()
      user2 = Central.Helpers.GeneralTestLib.make_user()

      # Join first user
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user1.id)
      {:ok, stats} = Matchmaking.get_stats(queue_id)

      assert stats == %{
               total_joined: 1,
               total_left: 0,
               total_matched: 0,
               total_wait_time_s: 0,
               player_count: 1
             }

      # Join second user (this should trigger a match)
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user2.id)

      # Trigger the tick with a specific time for testing
      now = DateTime.utc_now()
      queue_pid = Matchmaking.QueueRegistry.lookup(queue_id)
      send(queue_pid, {:tick, now})

      # Check that wait time was recorded
      {:ok, stats} = Matchmaking.get_stats(queue_id)
      assert stats.total_joined == 2
      assert stats.total_matched == 1
      # Wait time should be calculated based on the time we passed
      assert stats.total_wait_time_s >= 0
    end
  end
end
