defmodule Teiserver.TachyonLobby.Events.CancelKickVote do
  @moduledoc """
  Take care of cancelling a potential kickban vote when a player/spec
  leaves the lobby.
  """
  alias Teiserver.Account.User

  @enforce_keys [:user_id]
  defstruct [:user_id]

  @type t() :: %__MODULE__{
          user_id: User.id()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.CancelKickVote do
  alias Teiserver.TachyonLobby.Events
  alias Teiserver.TachyonLobby.Events.CancelKickVote
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%CancelKickVote{} = ev, %LT.Aggregate{} = agg) do
    case agg.data.current_vote do
      %{action: {:kickban, user_id, nil}} when user_id == ev.user_id ->
        end_event = %Events.VoteEnded{
          finished_at: DateTime.utc_now(),
          vote: agg.data.current_vote,
          outcome: :cancelled
        }

        Teiserver.TachyonLobby.Event.apply_event(end_event, agg)

      _other ->
        agg
    end
  end
end
