defmodule Teiserver.Game.RatingLib do
  alias Teiserver.{Account, Game, Battle}
  # alias Teiserver.Data.Types, as: T
  alias Central.Repo

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
  defp do_rate_match(match) do
    rating_type_id = get_match_type(match)
    stat_key = "rating-#{rating_type_id}"

    # Remove existing ratings for this match
    query = "DELETE FROM teiserver_game_rating_logs WHERE match_id = #{match.id}"
    Ecto.Adapters.SQL.query(Repo, query, [])

    match.members
      |> Enum.each(fn membership ->
        change = case membership.win do
          true -> 20
          false -> -15
          nil -> nil
        end

        if change != nil do
          stats = Account.get_user_stat_data(membership.user_id)
          existing_rating = Map.get(stats, stat_key, 500)
          Account.update_user_stat(membership.user_id, %{stat_key => existing_rating + change})
        end
      end)

    :ok
  end

  def reset_player_ratings do
    empty_data = ["Duel", "FFA", "Team FFA", "Small Team", "Large Team"]
      |> Map.new(fn name ->
        rating_type_id = Game.get_or_add_rating_type(name)

        {"rating-#{rating_type_id}", 500}
      end)

    Account.list_users(
      limit: :infinity,
      select: [:id]
    )
      |> Enum.map(fn %{id: userid} ->
        Account.update_user_stat(userid, empty_data)
      end)
  end

  def get_player_rating(user_id) do
    stats = Account.get_user_stat_data(user_id)

    ["Duel", "FFA", "Team FFA", "Small Team", "Large Team"]
      |> Map.new(fn name ->
        rating_type_id = Game.get_or_add_rating_type(name)

        value = stats["rating-#{rating_type_id}"]
        {name, value}
      end)
  end

  def re_rate_all_matches() do
    # TODO: Add pagination for server
    Battle.list_matches(
      search: [
        game_type_in: ["Team", "Duel", "FFA", "Team FFA"],
        processed: true
      ],
      limit: :infinity,
      preload: [:members]
    )
      |> Enum.each(fn match -> rate_match(match) end)
  end

  def leaderboard(game_type) do

  end
end
