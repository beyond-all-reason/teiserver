defmodule Teiserver.TachyonLobby.Events.StartVote do
  @moduledoc """
  To change the tags for a lobby
  """

  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:vote_state]
  defstruct [:vote_state]

  @type t() :: %__MODULE__{
          vote_state: LT.VoteState.t()
        }
end

defimpl Teiserver.TachyonLobby.Event, for: Teiserver.TachyonLobby.Events.StartVote do
  alias Teiserver.TachyonLobby.Events.StartVote
  alias Teiserver.TachyonLobby.Types, as: LT

  def apply_event(%StartVote{} = ev, %LT.Aggregate{} = agg) do
    data = %{agg.data | current_vote: ev.vote_state, vote_idx: agg.data.vote_idx + 1}
    changes = Map.put(agg.changes, :current_vote, Map.from_struct(ev.vote_state))
    vote = ev.vote_state

    side_effects = [
      {:send_after, :timer.seconds(vote.duration_s), {:vote_timeout, vote.id}} | agg.side_effects
    ]

    %{agg | data: data, changes: changes, side_effects: side_effects}
  end
end
