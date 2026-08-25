defprotocol Teiserver.Party.Event do
  alias Teiserver.Party.Types, as: PT

  @doc """
  Given an event and an aggregate, returns the new aggregate.

  This function must be side-effect free, because many events may be folded
  together or rolled back before arriving to the final aggregate to be used
  by the lobby.
  """
  @spec apply_event(term(), PT.Aggregate.t()) :: PT.Aggregate.t()
  def apply_event(event, data)
end
