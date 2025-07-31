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

    pid =
      QueueServer.init_state(%{
        id: id,
        name: id,
        team_size: 1,
        team_count: 2,
        engines: ["spring", "recoil"],
        games: ["BAR test version", "BAR release version"]
      })
      |> QueueServer.child_spec()
      |> ExUnit.Callbacks.start_link_supervised!()

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
    test "initial stats are zero", %{queue_pid: queue_pid} do
      # Initially stats should be zero
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 0
      assert state.stats.total_left == 0
      assert state.stats.total_matched == 0
      assert state.stats.total_wait_time_s == 0
    end

    test "tracks joins and leaves", %{user: user, queue_id: queue_id, queue_pid: queue_pid} do
      # Initially stats should be zero
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 0
      assert state.stats.total_left == 0
      assert state.stats.total_matched == 0
      assert state.stats.total_wait_time_s == 0

      # Join the queue
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user.id)
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 1
      assert state.stats.total_left == 0

      # Leave the queue
      :ok = Matchmaking.leave_queue(queue_id, user.id)
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 1
      assert state.stats.total_left == 1
    end

    test "tracks party joins", %{queue_id: queue_id, queue_pid: queue_pid} do
      user1 = Central.Helpers.GeneralTestLib.make_user()
      party_id = UUID.uuid4()

      # Create a party with 1 player (valid for team_size: 1 queue)
      {:ok, _pid} = Matchmaking.party_join_queue(queue_id, party_id, [user1])
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      # No stats updated yet, party is pending
      assert state.stats.total_joined == 0

      # Now actually join the queue with the party
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user1.id, party_id)
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      # Now the player has joined
      assert state.stats.total_joined == 1
      assert state.stats.total_left == 0
    end

    test "tracks wait time when matches are created", %{queue_id: queue_id, queue_pid: queue_pid} do
      user1 = Central.Helpers.GeneralTestLib.make_user()
      user2 = Central.Helpers.GeneralTestLib.make_user()

      # Join first user
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user1.id)
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 1
      assert state.stats.total_wait_time_s == 0

      # Wait for 1 second
      Process.sleep(1000)

      # Join second user (this should trigger a match)
      {:ok, _pid} = Matchmaking.join_queue(queue_id, user2.id)

      # Trigger the tick to process matches
      send(queue_pid, :tick)

      # Give it a moment to process
      Process.sleep(100)

      # Check that wait time was recorded
      {:ok, state} = GenServer.call(queue_pid, :get_state)
      assert state.stats.total_joined == 2
      assert state.stats.total_matched == 1
      # Wait time should be at least 1 second (from first user's wait)
      assert state.stats.total_wait_time_s >= 1
    end
  end
end
