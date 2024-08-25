defmodule Teiserver.Matchmaking do
  alias Teiserver.Matchmaking
  alias Teiserver.Data.Types, as: T

  @type queue :: Matchmaking.QueueServer.queue()
  @type queue_id :: Matchmaking.QueueServer.id()

  @spec lookup_queue(Matchmaking.QueueServer.id()) :: pid() | nil
  def lookup_queue(queue_id) do
    Matchmaking.QueueRegistry.lookup(queue_id)
  end

  @doc """
  Return the list of currently available queues
  """
  @spec list_queues() :: [{queue_id(), queue()}]
  def list_queues() do
    Matchmaking.QueueRegistry.list()
  end
end
