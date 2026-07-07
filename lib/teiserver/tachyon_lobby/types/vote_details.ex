defmodule Teiserver.TachyonLobby.Types.VoteDetails do
  @moduledoc """
  Public version of a vote record to be used with the lobby details
  """
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:vote, :finished_at, :outcome]
  defstruct [:vote, :finished_at, :outcome]

  @type t() :: %__MODULE__{
          vote: LT.VoteState.vote_outcome(),
          finished_at: DateTime.t(),
          outcome: LT.VoteState.vote_outcome()
        }
end
