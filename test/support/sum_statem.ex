defmodule Teiserver.Support.SumStatem do
  @moduledoc """
  A very simple state machine to help test replication

  The module comes with a supervisor that can be spawned in a test context.
  """

  alias ExUnit.Callbacks
  alias Teiserver.Cluster.DistributedGenStatem
  alias Teiserver.Cluster.Registry
  use DistributedGenStatem

  # setup/0 and setup_remote/0 are used to test various process without
  # having to slot them into the existing supervision tree of the main
  # teiserver application.
  def setup do
    Callbacks.start_link_supervised!({DynamicSupervisor, name: SumTestSupervisor})
    DynamicSupervisor.start_child(SumTestSupervisor, Registry)
  end

  # used to also start the supervisor on peer nodes. Cannot used ExUnit's
  # callbacks since the tests aren't running on the remote node.
  # It's fine to spawn an unsupervised task there because the lifetime of
  # the remote node is tied to the test.
  # Though maybe we should have a dynamic supervisor (and registry) for
  # clustering thing in the teiserver application?
  def setup_remote do
    ref = make_ref()
    parent = self()

    spawn(fn ->
      {:ok, _pid} = DynamicSupervisor.start_link(name: SumTestSupervisor)
      DynamicSupervisor.start_child(SumTestSupervisor, Registry)
      send(parent, ref)
      :timer.sleep(:infinity)
    end)

    receive do
      ^ref -> nil
    end
  end

  def lookup(id), do: {__MODULE__, id} |> Registry.lookup()
  def add(id, count \\ 1), do: call_process(id, {:add, count})
  def get(id), do: call_process(id, :get)
  def get_data(id), do: call_process(id, :get_data)

  @impl DistributedGenStatem
  def init(initial_count) do
    {:ok, :running, %{count: initial_count, replication_count: 0}}
  end

  @impl DistributedGenStatem
  def init_from_seed(_state, data) do
    # this is completely arbitrary, but it allows an easy way to trigger
    # a failure in remote initialisation
    if data.count < 0,
      do: {:error, :nope},
      else: :ok
  end

  @impl DistributedGenStatem
  def supervisor, do: SumTestSupervisor

  @impl DistributedGenStatem
  def name(id), do: Registry.via_tuple({__MODULE__, id})

  @impl DistributedGenStatem
  def handle_event({:call, from}, {:add, n}, _state, data) do
    {:replicate_state_and_data,
     {:keep_state, %{data | count: data.count + n}, [{:reply, from, :ok}]}}
  end

  def handle_event({:call, from}, :get, _state, data) do
    {:keep_state_and_data, [{:reply, from, data.count}]}
  end

  def handle_event({:call, from}, :get_data, _state, data) do
    {:keep_state_and_data, [{:reply, from, data}]}
  end

  @impl DistributedGenStatem
  def handle_replicate_state_and_data(from, peer_state, peer_data, state, _data) do
    new_data = %{peer_data | replication_count: peer_data.replication_count + 1}
    actions = [{:reply, from, :ok}]

    if peer_state == state,
      do: {:keep_state, new_data, actions},
      else: {:next_state, peer_state, new_data, actions}
  end

  defp call_process(id, msg) do
    DistributedGenStatem.call({__MODULE__, id}, msg, 10)
  catch
    :exit, {:noproc, _details} -> {:error, :invalid_sum}
  end
end
