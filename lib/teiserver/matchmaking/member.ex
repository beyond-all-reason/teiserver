defmodule Teiserver.Matchmaking.Member do
  @moduledoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @enforce_keys [:id, :player_ids, :joined_at]
  defstruct [
    :id,
    :player_ids,
    :joined_at,
    :rating,
    avoid: []
  ]

  alias Teiserver.Data.Types, as: T

  @typedoc """
  Aggregated player ratings for this member.
  This is the associated rating for the queue this member is in.
  For example %{skill: 23.4, uncertainty: 3.2}
  """
  @type rating :: %{skill: float(), uncertainty: float()}

  @typedoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @type t() :: %__MODULE__{
          id: binary(),
          player_ids: [T.userid()],
          rating: rating(),
          # aggregate of player to avoid for this member
          avoid: [T.userid()],
          joined_at: DateTime.t()
        }
end

defimpl GroupLength, for: Teiserver.Matchmaking.Member do
  def length(member), do: Kernel.length(member.player_ids)
end
