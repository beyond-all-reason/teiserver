defmodule Teiserver.Cluster.Registry do
  @moduledoc """
  mostly used for test, because it's simpler to spawn various process
  with semi-random names under a registry.
  """

  def child_spec(_arg) do
    Supervisor.child_spec(Registry,
      id: __MODULE__,
      start: {__MODULE__, :start_link, []}
    )
  end

  def start_link do
    Registry.start_link(keys: :unique, name: __MODULE__)
  end

  @spec via_tuple(id :: term()) :: GenServer.name()
  def via_tuple(id) do
    {:via, Registry, {__MODULE__, id}}
  end

  @spec lookup(id :: term()) :: pid() | nil
  def lookup(id) do
    case Registry.lookup(__MODULE__, id) do
      [{pid, _value}] -> pid
      _other -> nil
    end
  end
end
