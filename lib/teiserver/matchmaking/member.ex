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
  alias Teiserver.Battle.BalanceLib

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

  @doc """
  generate a member from the provided ids and game type (for ratings)
  """
  @spec new(T.userid() | [T.userid()], game_type :: String.t()) :: t()
  def new(player_ids, game_type) when not is_list(player_ids), do: new([player_ids], game_type)

  def new(player_ids, game_type) do
    %__MODULE__{
      id: UUID.uuid4(),
      player_ids: player_ids,
      rating: get_member_rating(player_ids, game_type),
      # TODO tachyon_mvp: fetch the list of player id avoided by this player
      avoid: [],
      joined_at: DateTime.utc_now()
    }
  end

  @spec get_member_rating([T.userid()], game_type :: String.t()) :: rating()
  def get_member_rating(player_ids, game_type) do
    default = BalanceLib.default_rating()
    default = %{skill: default.rating_value, uncertainty: default.uncertainty}

    case Enum.find(Teiserver.Game.get_ratings_for_users(player_ids), &(&1.name == game_type)) do
      nil ->
        default

      rt ->
        ratings = rt.ratings
        n = Enum.count(ratings)
        skill = Enum.sum_by(ratings, & &1.skill)
        uncertainty = Enum.sum_by(ratings, & &1.uncertainty)

        if n == 0,
          do: default,
          else: %{skill: skill / n, uncertainty: uncertainty / n}
    end
  end
end

defimpl GroupLength, for: Teiserver.Matchmaking.Member do
  def length(member), do: Kernel.length(member.player_ids)
end
