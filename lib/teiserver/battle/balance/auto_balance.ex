defmodule Teiserver.Battle.Balance.AutoBalance do
  @moduledoc """
  This will call other balancers depending on circumstances
  """
  alias Teiserver.Battle.Balance.SplitNoobs
  alias Teiserver.Battle.Balance.LoserPicks
  alias Teiserver.Battle.Balance.RespectAvoids
  alias Teiserver.Battle.Balance.BalanceTypes, as: BT
  alias Teiserver.Battle.Balance.AutoBalanceTypes, as: DB

  @doc """
  Main entry point used by balance_lib
  """
  @spec perform([BT.expanded_group()], non_neg_integer(), list()) :: any()
  def perform(expanded_group, team_count, opts \\ []) do
    get_balance_algorithm(expanded_group, team_count).perform(expanded_group, team_count, opts)
  end

  @spec get_balance_algorithm([BT.expanded_group()], integer()) ::
          any()
  def get_balance_algorithm(expanded_group, team_count) do
    cond do
      team_count != 2 ->
        LoserPicks

      true ->
        players = flatten_members(expanded_group)
        num_players = Enum.count(players)

        cond do
          # respect_avoids keeps parties if it can find a combination where team ratings are similar. It could potentially allow op parties. If there is NOT an op party, respect_avoids is less risky and can be used.
          # respect_avoids also treats noobs as worst in lobby.
          num_players <= 16 && !has_op_party?(players) -> RespectAvoids
          # split_noobs will keep parties together if it can find a combination where team rating is similar and team standard deviation is similar. It can split up op parties if it would result in team standard deviation diff that is too large.
          has_noobs?(players) -> SplitNoobs
          get_parties_count(expanded_group) >= 1 -> SplitNoobs
          true -> LoserPicks
        end
    end
  end

  @doc """
  Converts the input to a simple list of players
  """
  @spec flatten_members([BT.expanded_group()]) :: [DB.player()]
  def flatten_members(expanded_group) do
    players_with_party_id =
      Enum.with_index(expanded_group, fn element, index ->
        Map.put(element, :party_id, index)
      end)

    # We only care about ranks and uncertainties for now
    # However, in the future we may use other data to decide what balance algorithm to use,
    # e.g. whether there are parties or not, whether it's a high rating lobby, etc.
    for %{
          ranks: ranks,
          uncertainties: uncertainties,
          ratings: ratings,
          party_id: party_id
        } <- players_with_party_id,
        # Zipping will create binary tuples from 2 lists
        {rank, uncertainty, rating} <-
          Enum.zip([ranks, uncertainties, ratings]),
        do: %{
          uncertainty: uncertainty,
          rank: rank,
          rating: rating,
          party_id: party_id
        }
  end

  @spec get_parties_count([BT.expanded_group()]) :: number()
  def get_parties_count(expanded_group) do
    Enum.filter(expanded_group, fn x ->
      x[:count] >= 2
    end)
    |> Enum.count()
  end

  @spec has_noobs?([DB.player()]) :: any()
  def has_noobs?(players) do
    Enum.any?(players, fn x ->
      SplitNoobs.is_newish_player?(x.rank, x.uncertainty)
    end)
  end

  # If the top two players are in the same party, this will return true
  @spec has_op_party?([DB.player()]) :: boolean()
  def has_op_party?(players) do
    if(Enum.count(players) >= 2) do
      sorted_players =
        Enum.sort_by(
          players,
          fn x ->
            x.rating
          end,
          :desc
        )

      best_player = Enum.at(sorted_players, 0)
      second_best_player = Enum.at(sorted_players, 1)

      best_player.party_id == second_best_player.party_id
    else
      false
    end
  end
end
