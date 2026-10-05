defmodule Teiserver.Cluster.DistributedGenStatemTest do
  alias Teiserver.Cluster
  alias Teiserver.Support.ClusterHelpers
  alias Teiserver.Support.Polling
  alias Teiserver.Support.SumStatem

  use Teiserver.DataCase

  setup_all {ClusterHelpers, :setup_distribution}

  describe "single node" do
    setup [:ensure_single_node]

    test "basic wrapper test" do
      SumStatem.setup()
      [_self] = Cluster.get_nodes()
      {:ok, _pid} = SumStatem.start(:sumid, 42)

      :ok = SumStatem.add(:sumid, 1)
      :ok = SumStatem.add(:sumid, 1)
      assert 44 == SumStatem.get(:sumid)
      assert is_pid(SumStatem.lookup(:sumid))
    end
  end

  test "starts process on the primary" do
    %{node: node} = start_node(:peer1)
    id = id_for_node(node)
    SumStatem.setup()
    SumStatem.start(id, 42)

    42 = SumStatem.get(id)
    refute is_pid(SumStatem.lookup(id))
    assert is_pid(:erpc.call(node, SumStatem, :lookup, [id]))
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
