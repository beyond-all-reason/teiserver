defmodule TeiserverWeb.Tachyon.PartyMatchmakingTest do
  @moduledoc """
  Special tests for party and matchmaking interactions.
  Assumes the basics of parties and matchmaking are working already
  """
  use Teiserver.DataCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.AssetFixtures
  alias Teiserver.Matchmaking.{QueueSupervisor, QueueServer}

  @moduletag :wip

  test "all members join matchmaking" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    [q1, q2] = [setup_queue(2), setup_queue(3)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id, q2.id])

    assert %{"commandId" => "matchmaking/queuesJoined", "data" => data} =
             Tachyon.recv_message!(m2.client)

    assert MapSet.new(data["queues"]) == MapSet.new([q1.id, q2.id])
  end

  test "parties are matched together" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    {_party_id, [m3, m4], _} = setup_party(2, 0)
    [q1] = [setup_queue(2)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id])
    assert %{"commandId" => "matchmaking/queuesJoined"} = Tachyon.recv_message!(m2.client)

    assert %{"status" => "success"} = Tachyon.join_queues!(m3.client, [q1.id])
    assert %{"commandId" => "matchmaking/queuesJoined"} = Tachyon.recv_message!(m4.client)

    send(q1.pid, :tick)

    for m <- [m1, m2, m3, m4] do
      assert %{"commandId" => "matchmaking/found"} = Tachyon.recv_message!(m.client)
    end
  end

  test "cannot join queues too small" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    [q1] = [setup_queue(1)]

    assert %{"status" => "failed", "reason" => "invalid_request"} =
             Tachyon.join_queues!(m1.client, [q1.id])

    assert {:error, :timeout} == Tachyon.recv_message(m2.client)
  end

  test "one member leaving matchmaking makes all member leave mm" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    [q1, q2] = [setup_queue(2), setup_queue(3)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id, q2.id])

    assert %{"commandId" => "matchmaking/queuesJoined"} = Tachyon.recv_message!(m2.client)

    assert %{"status" => "success"} = Tachyon.leave_queues!(m1.client)
    assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(m2.client)
  end

  test "one member leaving the party makes all member leave mm" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    [q1, q2] = [setup_queue(2), setup_queue(3)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id, q2.id])

    assert %{"commandId" => "matchmaking/queuesJoined"} =
             Tachyon.recv_message!(m2.client)

    assert %{"status" => "success"} = Tachyon.leave_party!(m1.client)
    assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(m1.client)

    msgs = Tachyon.drain(m2.client)

    assert Enum.count(msgs) == 2
    cmd_ids = Enum.map(msgs, fn msg -> msg["commandId"] end) |> MapSet.new()
    assert MapSet.new(["matchmaking/cancelled", "party/updated"]) == cmd_ids
  end

  test "invites get cancelled when entering matchmaking" do
    {_party_id, [m1, m2], [invited]} = setup_party(2, 1)
    [q1] = [setup_queue(2)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id])

    assert %{"commandId" => "party/removed"} = Tachyon.recv_message!(invited.client)
    assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(m1.client)

    msgs = Tachyon.drain(m2.client)
    assert Enum.count(msgs) == 2
    events = Enum.map(msgs, fn msg -> msg["commandId"] end) |> MapSet.new()
    assert events == MapSet.new(["party/updated", "matchmaking/queuesJoined"])
  end

  test "cannot invite when in matchmaking" do
    {_party_id, [m1, _m2], _} = setup_party(2, 0)
    [q1] = [setup_queue(2)]

    invited = setup_client()
    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id])

    assert %{"status" => "failed", "reason" => "invalid_request"} =
             Tachyon.invite_to_party!(m1.client, invited.user.id)
  end

  test "leave matchmaking when creating a party" do
    founder = setup_client()
    [q1] = [setup_queue(2)]
    assert %{"status" => "success"} = Tachyon.join_queues!(founder.client, [q1.id])

    assert %{"status" => "success"} = Tachyon.create_party!(founder.client)

    assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(founder.client)
  end

  test "leave matchmaking when entering a party" do
    {party_id, [founder], _} = setup_party(1, 0)
    [q1] = [setup_queue(2)]
    to_invite = setup_client()

    assert %{"status" => "success"} = Tachyon.join_queues!(to_invite.client, [q1.id])
    assert %{"status" => "success"} = Tachyon.invite_to_party!(founder.client, to_invite.user.id)
    assert %{"commandId" => "party/invited"} = Tachyon.recv_message!(to_invite.client)
    assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(founder.client)

    assert %{"status" => "success"} = Tachyon.accept_party_invite!(to_invite.client, party_id)
    assert %{"commandId" => "party/updated"} = Tachyon.recv_message!(founder.client)

    messages = Tachyon.drain(to_invite.client)
    commands = Enum.map(messages, &Map.get(&1, "commandId")) |> MapSet.new()
    assert MapSet.new(["matchmaking/cancelled", "party/updated"]) == commands
  end

  test "queue crash reset party matchmaking state" do
    {_party_id, [m1, m2], _} = setup_party(2, 0)
    [q1, q2] = [setup_queue(2), setup_queue(3)]

    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q1.id])
    assert %{"commandId" => "matchmaking/queuesJoined"} = Tachyon.recv_message!(m2.client)

    Process.exit(q1.pid, :exit)
    assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(m1.client)
    assert %{"commandId" => "matchmaking/cancelled"} = Tachyon.recv_message!(m2.client)

    # can still join the other queue
    assert %{"status" => "success"} = Tachyon.join_queues!(m1.client, [q2.id])
    assert %{"commandId" => "matchmaking/queuesJoined"} = Tachyon.recv_message!(m2.client)
  end

  # setup n members and m invited users to a party
  defp setup_party(n_members, n_invited) do
    # start = :erlang.monotonic_time(:millisecond)
    founder = setup_client()

    members =
      if n_members > 1 do
        rest =
          Enum.map(1..(n_members - 1), fn _ -> setup_client() end)

        [founder | rest]
      else
        [founder]
      end

    assert %{"status" => "success", "data" => %{"partyId" => party_id}} =
             Tachyon.create_party!(founder.client)

    for member <- tl(members) do
      assert %{"status" => "success"} = Tachyon.invite_to_party!(founder.client, member.user.id)
    end

    for m <- tl(members) do
      :ok = Tachyon.send_request(m.client, "party/acceptInvite", %{partyId: party_id})
    end

    Task.await_many(Enum.map(members, fn m -> Task.async(fn -> Tachyon.drain(m.client) end) end))

    invited =
      if n_invited == 0 do
        []
      else
        Enum.map(1..n_invited, fn _ ->
          ctx = setup_client()

          assert %{"status" => "success"} =
                   Tachyon.invite_to_party!(founder.client, ctx.user.id)

          ctx
        end)
      end

    Task.await_many(
      Enum.map(members ++ invited, fn m -> Task.async(fn -> Tachyon.drain(m.client) end) end)
    )

    # duration = :erlang.monotonic_time(:millisecond) - start
    # IO.puts("setup party took #{duration} ms")
    {party_id, members, invited}
  end

  defp setup_queue(team_size) do
    queue_id = UUID.uuid4()

    map_attrs = %{
      spring_name: "Rosetta " <> queue_id,
      display_name: "Rosetta",
      thumbnail_url: "https://www.beyondallreason.info/map/rosetta",
      matchmaking_queues: [queue_id]
    }

    AssetFixtures.create_map(map_attrs)

    map_attrs = %{
      id: queue_id,
      name: queue_id,
      team_size: team_size,
      team_count: 2,
      settings: %{tick_interval_ms: :manual, max_distance: 15},
      engines: [%{version: "2025.04.01"}],
      games: [%{spring_game: "BAR-27948-17aa95a"}],
      maps: Teiserver.Asset.get_maps_for_queue(queue_id)
    }

    {:ok, pid} =
      QueueServer.init_state(map_attrs)
      |> QueueSupervisor.start_queue!()

    %{id: queue_id, pid: pid}
  end

  defp setup_client() do
    {:ok, args} = Tachyon.setup_client()
    Map.new(args)
  end
end
