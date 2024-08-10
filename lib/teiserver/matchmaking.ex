defmodule Teiserver.Matchmaking do
  alias Teiserver.Matchmaking

  @spec lookup_queue(Matchmaking.QueueServer.id()) :: pid() | nil
  def lookup_queue(queue_id) do
    Matchmaking.QueueRegistry.lookup(queue_id)
  end
end
