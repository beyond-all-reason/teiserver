defmodule Teiserver.Game.RatingLib do
  alias Teiserver.{Account, Game, Battle}
  alias Teiserver.Data.Types, as: T
  alias Central.Repo
  require Logger

  @spec rate_match(non_neg_integer() | Teiserver.Battle.Match.t()) :: :ok | {:error, :no_match}
  def rate_match(match_id) when is_integer(match_id) do
    Battle.get_match(match_id, preload: [:members])
      |> rate_match()
  end

  def rate_match(nil), do: {:error, :no_match}
  def rate_match(match) do
    cond do
      not Enum.member?(["Team", "Duel", "FFA", "Team FFA"], match.game_type) ->
        {:error, :invalid_game_type}

      match.processed == false ->
        {:error, :not_processed}

      true ->
        do_rate_match(match)
    end
  end

  @spec get_match_type(map()) :: non_neg_integer()
  defp get_match_type(match) do
    name = case match.game_type do
      "Duel" -> "Duel"
      "FFA" -> "FFA"
      "Team FFA" -> "Team FFA"
      "Team" ->
        cond do
          match.team_size <= 4 -> "Small Team"
          match.team_size > 4 -> "Large Team"
        end
    end

    Game.get_or_add_rating_type(name)
  end

  @spec do_rate_match(Teiserver.Battle.Match.t()) :: :ok
  # Currently don't support more than 2 teams
  defp do_rate_match(%{team_count: 2} = match) do
    rating_type_id = get_match_type(match)
    stat_key = "rating-#{rating_type_id}"

    # Remove existing ratings for this match
    query = "DELETE FROM teiserver_game_rating_logs WHERE match_id = #{match.id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    winners = match.members
      |> Enum.filter(fn membership -> membership.win end)

    losers = match.members
      |> Enum.reject(fn membership -> membership.win end)

    winner_ratings = winners
      |> Enum.map(fn membership ->
        stats = Account.get_user_stat_data(membership.user_id)
        Map.get(stats, stat_key, default_rating()) |> List.to_tuple()
      end)

    loser_ratings = losers
      |> Enum.map(fn membership ->
        stats = Account.get_user_stat_data(membership.user_id)
        Map.get(stats, stat_key, default_rating()) |> List.to_tuple()
      end)

    [win_result, lose_result] = Openskill.rate([winner_ratings, loser_ratings])

    Enum.zip(winners, win_result)
      |> Enum.map(fn {membership, new_rating} ->
        new_rating = Tuple.to_list(new_rating)
        Account.update_user_stat(membership.user_id, %{stat_key => new_rating})
        rating_log = Game.create_rating_log(%{
          user_id: membership.user_id,
          rating_type_id: rating_type_id,
          match_id: match.id,

          value: %{rating: new_rating}
        })

        case rating_log do
          {:ok, rating_log} -> rating_log
          {:error, changeset} ->
            Logger.error("Error saving rating log: #{Kernel.inspect changeset}")
            nil
        end
      end)

    Enum.zip(losers, lose_result)
      |> Enum.map(fn {membership, new_rating} ->
        new_rating = Tuple.to_list(new_rating)
        Account.update_user_stat(membership.user_id, %{stat_key => new_rating})
      end)

    :ok
  end
  defp do_rate_match(%{}), do: :ok

  @spec reset_player_ratings() :: :ok
  def reset_player_ratings do
    # Delete all rating logs
    Ecto.Adapters.SQL.query(Repo, "DELETE FROM teiserver_game_rating_logs", [])

    # Create default data for players
    empty_data = ["Duel", "FFA", "Team FFA", "Small Team", "Large Team"]
      |> Map.new(fn name ->
        rating_type_id = Game.get_or_add_rating_type(name)

        {"rating-#{rating_type_id}", default_rating()}
      end)

    Account.list_users(
      limit: :infinity,
      select: [:id]
    )
      |> Enum.each(fn %{id: userid} ->
        Account.update_user_stat(userid, empty_data)
      end)
  end

  @spec get_player_rating(T.userid()) :: map
  def get_player_rating(user_id) do
    stats = Account.get_user_stat_data(user_id)

    ["Duel", "FFA", "Team FFA", "Small Team", "Large Team"]
      |> Map.new(fn name ->
        rating_type_id = Game.get_or_add_rating_type(name)

        value = stats["rating-#{rating_type_id}"]
        {name, value}
      end)
  end

  @spec re_rate_all_matches :: :ok
  def re_rate_all_matches() do
    start_time = System.system_time(:millisecond)

    match_ids = Battle.list_matches(
      search: [
        game_type_in: ["Team", "Duel", "FFA", "Team FFA"],
        processed: true
      ],
      limit: :infinity,
      select: [:id]
    )
    |> Enum.map(fn %{id: id} -> id end)

    match_count = Enum.count(match_ids)

    match_ids
      |> Enum.chunk_every(50)
      |> Enum.each(fn ids ->
        re_rate_specific_matches(ids)
      end)

    time_taken = System.system_time(:millisecond) - start_time
    Logger.info("re_rate_all_matches, took #{time_taken}ms for #{match_count} matches")
  end

  defp re_rate_specific_matches(ids) do
    Battle.list_matches(
      search: [
        id_in: ids
      ],
      limit: :infinity,
      preload: [:members]
    )
    |> Enum.each(fn match -> rate_match(match) end)
  end

  @spec default_rating :: List.t()
  def default_rating() do
    Openskill.rating()
      |> Tuple.to_list()
  end

  def leaderboard(game_type) do

  end
end
