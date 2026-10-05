defmodule Teiserver.Support.SumStatem do
  @moduledoc """
  A very simple state machine to help test replication

  The module comes with a supervisor that can be spawned in a test context.
  """

  alias ExUnit.Callbacks
  alias Teiserver.Cluster.DistributedGenStatem
  use DistributedGenStatem

  def setup do
    Callbacks.start_link_supervised!({DynamicSupervisor, name: SumTestSupervisor})
  end

  def add(id, count \\ 1), do: call_process(id, {:add, count})
  def get(id), do: call_process(id, :get)

  @impl DistributedGenStatem
  def init(initial_count) do
    {:ok, :running, initial_count}
  end

  @impl DistributedGenStatem
  def supervisor, do: SumTestSupervisor

  @impl DistributedGenStatem
  def name(id), do: {:local, id}

  @impl DistributedGenStatem
  def handle_event({:call, from}, {:add, n}, _state, count) do
    {:keep_state, count + n, [{:reply, from, :ok}]}
  end

  def handle_event({:call, from}, :get, _state, count) do
    {:keep_state_and_data, [{:reply, from, count}]}
  end

  defp call_process(id, msg) do
    DistributedGenStatem.call(id, msg, 10)
  end
end
