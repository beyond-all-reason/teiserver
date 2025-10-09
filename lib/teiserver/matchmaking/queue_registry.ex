defmodule Teiserver.Matchmaking.QueueRegistry do
  @moduledoc """
  cluster wide registry of all matchmaking queues

  The registry is also used for listing and querying running queues
  """

  alias Teiserver.Matchmaking.QueueServer

  def start_link() do
    Horde.Registry.start_link(keys: :unique, members: :auto, name: __MODULE__)
  end

  @doc """
  How to reach a given queue from its ID
  """
  @spec via_tuple(QueueServer.id()) :: GenServer.name()
  def via_tuple(queue_id) do
    {:via, Horde.Registry, {__MODULE__, queue_id}}
  end

  @doc """
  Used for registering a new queue with some associated data
  """
  @spec via_tuple(QueueServer.id(), QueueServer.queue()) :: GenServer.name()
  def via_tuple(queue_id, queue_data) do
    {:via, Horde.Registry, {__MODULE__, queue_id, queue_data}}
  end

  def child_spec(_arg) do
    Supervisor.child_spec(Horde.Registry, id: __MODULE__, start: {__MODULE__, :start_link, []})
  end

  @spec lookup(QueueServer.id()) :: pid() | nil
  def lookup(queue_id) do
    case Horde.Registry.lookup(__MODULE__, queue_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @spec list() :: [{QueueServer.id(), QueueServer.queue()}]
  def list() do
    Horde.Registry.select(__MODULE__, [{{:"$1", :_, :"$2"}, [], [{{:"$1", :"$2"}}]}])
  end

  def update_value(id, callback) do
    Horde.Registry.update_value(__MODULE__, id, callback)
  end
end
