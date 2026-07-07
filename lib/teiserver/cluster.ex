defmodule Teiserver.Cluster do
  @moduledoc """
  Utilities to work with multiple nodes
  """

  @doc """
  returns the primary node for the given routing key and the list
  of replica (in no particular order)

  This uses rendez-vous hashing to split the nodes
  """
  @spec split_nodes(term()) :: {node(), [node()]}
  def split_nodes(routing_key) do
    [primary | replicas] =
      [Node.self() | Node.list(:connected)]
      |> Enum.sort_by(fn node -> :erlang.phash2({node, routing_key}) end)

    {primary, replicas}
  end

  def primary?(routing_key, node \\ Node.self()) do
    {primary, _replicas} = split_nodes(routing_key)
    primary == node
  end

  @doc """
  Same as `Kernel.apply/3` but will run the given mfa on the primary and
  the replicas. It will wait for the primary and a majority of replicas to
  return before returning the result of the primary

  Note that this function doesn't (yet) handle exceptions. If the given mfa
  raises an error, then it'll blow up this function, and all results will be lost
  with the target nodes in undefined state.
  """
  def replicated_apply(routing_key, {m, f, a}, timeout \\ :timer.seconds(5)) do
    {primary, replicas} = split_nodes(routing_key)

    reqs =
      Enum.reduce([primary | replicas], :erpc.reqids_new(), fn n, reqs ->
        :erpc.send_request(n, m, f, a, n, reqs)
      end)

    # for now(?) we wait for *all* replicas. This may change in the future, though
    # it is unlikely. 3 nodes should be plenty enough, so 2 replicas will always
    # be needed
    # This function also discard results from the replicas and only keep the one
    # from the primary. A potential improvement would be to compare these results
    # and raise or return an error if replicas give different results
    resps = receive_responses(reqs, timeout)
    resps[primary]
  end

  defp receive_responses(reqs, timeout, result \\ %{}) do
    case :erpc.receive_response(reqs, timeout, true) do
      :no_request -> result
      {res, label, reqs} -> receive_responses(reqs, timeout, Map.put(result, label, res))
    end
  end
end
