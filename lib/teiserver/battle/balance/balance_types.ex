defmodule Teiserver.Battle.Balance.BalanceTypes do
  @moduledoc false
  # alias Teiserver.Battle.Balance.BalanceTypes, as: BT

  alias Teiserver.Data.Types, as: T

  @type rating_value() :: float()
  @type player_group() :: %{T.userid() => rating_value()}
  @type expanded_group() :: %{
          members: [T.userid()],
          ratings: [rating_value()],
          names: [String.t()],
          ranks: [non_neg_integer()],
          group_rating: rating_value(),
          count: non_neg_integer(),
          uncertainties: [number()]
        }

  @type group() :: %{
          members: [T.userid()],
          ratings: [rating_value()],
          group_rating: rating_value(),
          count: non_neg_integer()
        }
  @type expanded_group_or_pair() :: expanded_group() | {expanded_group(), expanded_group()}

  @type algorithm_result :: map()

  @type balance_result :: %{
          teams: map,
          team_groups: map,
          team_players: map,
          time_taken: number,
          logs: list
        }
end
