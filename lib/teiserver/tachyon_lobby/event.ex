defprotocol Teiserver.TachyonLobby.Event do
  alias Teiserver.TachyonLobby.Types, as: LT

  @doc """
  Given an event and an aggregate, returns the new aggregate.

  This function must be side-effect free, because many events may be folded
  together or rolled back before arriving to the final aggregate to be used
  by the lobby.
  """
  @spec apply_event(term(), LT.Aggregate.t()) :: LT.Aggregate.t()
  def apply_event(event, data)
end
