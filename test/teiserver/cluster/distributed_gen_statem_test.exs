defmodule Teiserver.Cluster.DistributedGenStatemTest do
  alias Teiserver.Cluster
  alias Teiserver.Support.ClusterHelpers
  alias Teiserver.Support.Polling
  alias Teiserver.Support.SumStatem

  use Teiserver.DataCase

  setup_all {ClusterHelpers, :setup_distribution}
  setup [:sumstatem_setup, :ensure_single_node]

  def sumstatem_setup(_ctx) do
    SumStatem.setup()
    :ok
  end

  describe "single node" do
    test "no process" do
      {:error, :invalid_sum} = SumStatem.get(:nothing)
    end

    test "basic wrapper test" do
      [_self] = Cluster.get_nodes()
      {:ok, _pid} = SumStatem.start(:sumid, 42)

      :ok = SumStatem.add(:sumid, 1)
      :ok = SumStatem.add(:sumid, 1)
      assert 44 == SumStatem.get(:sumid)
      assert is_pid(SumStatem.lookup(:sumid))
    end
  end

  test "create all replica at creation" do
    %{node: node, server_pid: server_pid} = start_node(:peer1)
    id = id_for_node(node)
    {:ok, pid} = SumStatem.start(id, 42)

    assert is_pid(SumStatem.lookup(id))
    assert is_pid(:erpc.call(node, SumStatem, :lookup, [id]))

    42 = SumStatem.get(id)

    ref = Process.monitor(pid)
    :peer.stop(server_pid)
    assert_receive {:DOWN, ^ref, :process, _pid, _reason}

    # still works
    42 = SumStatem.get(id)
  end

  test "setup primary on new node on call" do
    node_name = :peer1
    # this maps to :peer1 once started
    id = "sumid-0"
    SumStatem.start(id, 42)

    %{} = start_node(node_name)
    42 = SumStatem.get(id)
    SumStatem.add(id, 1)
    43 = SumStatem.get(id)
  end

  describe "init callback from seed" do
    test "works" do
      node_name = :peer1
      # this maps to :peer1 once started
      id = "sumid-0"
      {:ok, pid} = SumStatem.start(id, 42)
      ref = Process.monitor(pid)

      %{node: node} = start_node(node_name)
      42 = SumStatem.get(id)
      refute_receive({:DOWN, ^ref, :process, _pid, _reason})
      assert is_pid(:erpc.call(node, SumStatem, :lookup, [id], 100))
    end

    test "kill all process when fails" do
      node_name = :peer1
      # this maps to :peer1 once started
      id = "sumid-0"
      {:ok, pid} = SumStatem.start(id, -5)
      ref = Process.monitor(pid)

      %{} = start_node(node_name)
      {:error, :invalid_sum} = SumStatem.get(id)
      assert_receive({:DOWN, ^ref, :process, _pid, _reason})
    end
  end

  describe "replication" do
    test "can replicate whole state and data" do
      %{node: node, server_pid: server_pid} = start_node(:peer1)
      id = id_for_node(node)
      {:ok, pid} = SumStatem.start(id, 42)
      :ok = SumStatem.add(id, 2)
      ref = Process.monitor(pid)

      :ok = :peer.stop(server_pid)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}

      44 = SumStatem.get(id)
      assert SumStatem.get_data(id).replication_count == 1
    end

    test "can replicate events" do
      %{node: node, server_pid: server_pid} = start_node(:peer1)
      id = id_for_node(node)
      {:ok, pid} = SumStatem.start(id, 42)
      :ok = SumStatem.sub(id, 2)
      ref = Process.monitor(pid)

      :ok = :peer.stop(server_pid)
      assert_receive {:DOWN, ^ref, :process, _pid, _reason}

      40 = SumStatem.get(id)
      assert SumStatem.get_data(id).replication_count == 0
    end
  end

  defp id_for_node(node) do
    Stream.from_index()
    |> Stream.map(fn i -> "sumid-#{i}" end)
    |> Stream.filter(fn id ->
      {primary, _replicas} = SumStatem.routing_key(id) |> Cluster.split_nodes()
      primary == node
    end)
    |> Enum.at(0)
  end

  defp start_node(name) do
    {server_pid, node} = ClusterHelpers.start_node(name)
    :erpc.call(node, SumStatem, :setup_remote, [])
    %{server_pid: server_pid, node: node}
  end

  # under some circumstances, a peer node started by another test may still
  # be seen as alive and connected, which makes any test relying on a single
  # node being around flaky
  defp ensure_single_node(_ctx) do
    Polling.poll_until(&Cluster.get_nodes/0, fn nodes -> length(nodes) == 1 end)
    :ok
  end
end
