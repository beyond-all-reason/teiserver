defmodule Teiserver.TachyonLobby.Types.VoteRecord do
  @moduledoc """
  Used for the vote history of a lobby
  """
  alias Teiserver.TachyonLobby.Types, as: LT

  @enforce_keys [:vote, :finished_at, :outcome]
  defstruct [:vote, :finished_at, :outcome]

  @type t() :: %__MODULE__{
          vote: LT.VoteState.t(),
          finished_at: DateTime.t(),
          outcome: LT.VoteState.vote_outcome()
        }
end
