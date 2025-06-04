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
    rating: %{},
    avoid: []
  ]

  alias Teiserver.Data.Types, as: T

  @typedoc """
  member of a queue. Holds of the information required to match members together.
  A member can be a party of players. Parties must not be broken.
  """
  @type t() :: %__MODULE__{
          id: binary(),
          player_ids: [T.userid()],
          # maybe also add (aggregated) chevron if that's taking into account
          # map keyed by the rating type to {skill, uncertainty}
          # For example %{"duel" => {12, 3.2}}
          rating: %{String.t() => {integer(), integer()}},
          # aggregate of player to avoid for this member
          avoid: [T.userid()],
          joined_at: DateTime.t()
        }
end

defimpl GroupLength, for: Teiserver.Matchmaking.Member do
  def length(member), do: Kernel.length(member.player_ids)
end
