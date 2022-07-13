defmodule Teiserver.Game.MatchRatingLib do
  @moduledoc """
  This module is used purely for rating calculations, it is not used
  to balance matches. For that use Teiserver.Battle.BalanceLib.
  """

  alias Teiserver.{Account, Game, Battle}
  alias Teiserver.Data.Types, as: T
  alias Central.Repo
  alias Teiserver.Battle.BalanceLib
  require Logger
  alias Decimal, as: D

  @rated_match_types ["Team", "Duel", "FFA", "Team FFA"]

  @spec rating_type_list() :: [String.t()]
  def rating_type_list() do
    ["Duel", "FFA", "Team FFA", "Small Team", "Large Team"]
  end

  @spec rating_type_id_lookup() :: map()
  def rating_type_id_lookup() do
    rating_type_list()
      |> Map.new(fn name -> {Game.get_or_add_rating_type(name), name} end)
  end

  @spec rating_type_name_lookup() :: map()
  def rating_type_name_lookup() do
    rating_type_list()
      |> Map.new(fn name -> {name, Game.get_or_add_rating_type(name)} end)
  end

  @spec rate_match(non_neg_integer() | Teiserver.Battle.Match.t()) :: :ok | {:error, :no_match}
  def rate_match(match_id) when is_integer(match_id) do
    Battle.get_match(match_id, preload: [:members])
      |> rate_match()
  end

  def rate_match(nil), do: {:error, :no_match}
  def rate_match(match) do
    logs = Game.list_rating_logs(search: [match_id: match.id], limit: 1, select: [:id])

    cond do
      not Enum.member?(@rated_match_types, match.game_type) ->
        {:error, :invalid_game_type}

      match.processed == false ->
        {:error, :not_processed}

      match.winning_team == nil ->
        {:error, :no_winning_team}

      not Enum.empty?(logs) ->
        {:error, :already_rated}

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
  defp do_rate_match(%{team_count: _2} = match) do
    rating_type_id = get_match_type(match)

    winners = match.members
      |> Enum.filter(fn membership -> membership.win end)

    losers = match.members
      |> Enum.reject(fn membership -> membership.win end)

    # We will want to update these so we keep the whole object
    rating_lookup = match.members
      |> Map.new(fn membership ->
        rating = Account.get_rating(membership.user_id, rating_type_id)
        {membership.user_id, rating}
      end)

    # Build ratings into lists of tuples for the OpenSkill module to handle
    winner_ratings = winners
      |> Enum.map(fn membership ->
        rating = rating_lookup[membership.user_id] || BalanceLib.default_rating(rating_type_id)
        {rating.mu |> D.to_float, rating.sigma |> D.to_float}
      end)

    loser_ratings = losers
      |> Enum.map(fn membership ->
        rating = rating_lookup[membership.user_id] || BalanceLib.default_rating(rating_type_id)
        {rating.mu |> D.to_float, rating.sigma |> D.to_float}
      end)

    # Run the actual calculation
    [win_result, lose_result] = Openskill.rate([winner_ratings, loser_ratings])

    # Save the results
    win_ratings = Enum.zip(winners, win_result)
      |> Enum.map(fn {%{user_id: user_id}, rating_update} ->
        user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
        do_update_rating(user_id, match.id, user_rating, rating_update)
      end)

    loss_ratings = Enum.zip(losers, lose_result)
      |> Enum.map(fn {%{user_id: user_id}, rating_update} ->
        user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
        do_update_rating(user_id, match.id, user_rating, rating_update)
      end)


    Ecto.Multi.new()
      |> Ecto.Multi.insert_all(:insert_all, Teiserver.Game.RatingLog, win_ratings ++ loss_ratings)
      |> Central.Repo.transaction()

    :ok
  end
  defp do_rate_match(_), do: :ok

  @spec do_update_rating(T.userid, T.match_id(), map(), {number(), number()}) :: any
  defp do_update_rating(user_id, match_id, user_rating, rating_update) do
    # It's possible they don't yet have a rating
    user_rating = if Map.get(user_rating, :user_id) do
      user_rating
    else
      {:ok, rating} = Account.create_rating(Map.merge(user_rating, %{
        user_id: user_id
      }))
      rating
    end

    rating_type_id = user_rating.rating_type_id
    {new_mu, new_sigma} = rating_update
    new_ordinal = Openskill.ordinal(rating_update)

    Account.update_rating(user_rating, %{
      ordinal: new_ordinal,
      mu: new_mu,
      sigma: new_sigma
    })

    %{
      user_id: user_id,
      rating_type_id: rating_type_id,
      match_id: match_id,

      value: %{
        ordinal: new_ordinal,
        mu: new_mu,
        sigma: new_sigma,

        old_ordinal: D.to_float(user_rating.ordinal),
        old_mu: D.to_float(user_rating.mu),
        old_sigma: D.to_float(user_rating.sigma),

        ordinal_change: new_ordinal - D.to_float(user_rating.ordinal),
        mu_change: new_mu - D.to_float(user_rating.mu),
        sigma_change: new_sigma - D.to_float(user_rating.sigma),
      }
    }
  end

  @spec reset_player_ratings() :: :ok
  def reset_player_ratings do
    # Delete all ratings and rating logs
    Ecto.Adapters.SQL.query(Repo, "DELETE FROM teiserver_game_rating_logs", [])
    Ecto.Adapters.SQL.query(Repo, "DELETE FROM teiserver_account_ratings", [])

    :ok
  end

  @spec get_player_rating(T.userid()) :: map
  def get_player_rating(user_id) do
    stats = Account.get_user_stat_data(user_id)

    rating_type_list()
      |> Map.new(fn name ->
        rating_type_id = Game.get_or_add_rating_type(name)

        rating = stats["rating-#{rating_type_id}"]
        ordinal = stats["ordinal-#{rating_type_id}"]
        {name, {ordinal, rating}}
      end)
  end

  @spec re_rate_all_matches :: non_neg_integer()
  def re_rate_all_matches() do
    match_ids = Battle.list_matches(
      search: [
        game_type_in: @rated_match_types,
        processed: true
      ],
      order_by: "Oldest first",
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

    match_count
  end

  @spec reset_and_re_rate() :: :ok
  def reset_and_re_rate() do
    start_time = System.system_time(:millisecond)

    reset_player_ratings()
    match_count = re_rate_all_matches()

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
    |> Enum.map(fn match -> rate_match(match) end)
  end

  @spec predict_winning_team([map()], non_neg_integer()) :: map()
  def predict_winning_team(players, rating_type_id) do
    team_scores = players
      |> Enum.group_by(
        fn %{team_id: team_id} -> team_id end,
        fn %{user_id: user_id} -> user_id end
      )
      |> Enum.map(fn {team_id, user_ids} ->
        score = user_ids
        |> Enum.reduce(0, fn (user_id, acc) ->
          acc + BalanceLib.get_user_rating_value(user_id, rating_type_id)
        end)

        {team_id, score}
      end)

    winning_team = team_scores
      |> Enum.sort_by(fn {_id, score} -> score end, &>=/2)
      |> hd
      |> elem(0)

    %{
      winning_team: winning_team,
      team_scores: team_scores
    }
  end


  # The following is used purely for testing the rating algorithm, it is not intended to be used elsewhere
  defp predict_match(match_id) when is_integer(match_id) do
    Battle.get_match!(match_id, preload: [:members])
      |> predict_match()
  end

  defp predict_match(match) do
    rating_type_id = get_match_type(match)
    predict_winning_team(match.members, rating_type_id) |> Map.get(:winning_team)
  end

  def test_predictions() do
    results = Battle.list_matches(
      search: [
        # game_type_in: ["Team FFA"],
        game_type_in: @rated_match_types,
        processed: true,
        started_after: Timex.now |> Timex.shift(days: -31)
      ],
      limit: :infinity,
      preload: [:members]
    )
      |> Enum.map(fn m ->
        prediction = predict_match(m)
        if prediction == m.winning_team, do: 1, else: 0
      end)

    match_count = Enum.count(results)
    correct_count = Enum.sum(results)

    [
      "Checked a total of #{match_count} matches",
      "Correct on #{correct_count} matches (#{correct_count/match_count})",
    ]
    |> Enum.join("\n")
    |> IO.puts
  end
end
