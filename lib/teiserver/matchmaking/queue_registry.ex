defmodule Teiserver.Matchmaking.QueueRegistry do
  @moduledoc """
  cluster wide registry of all matchmaking queues
  """

  alias Teiserver.Matchmaking.QueueServer

  def start_link() do
    Horde.Registry.start_link(keys: :unique, members: :auto, name: __MODULE__)
  end

  @spec via_tuple(QueueServer.id()) :: GenServer.name()
  def via_tuple(queue_id) do
    {:via, Horde.Registry, {__MODULE__, queue_id}}
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
end
