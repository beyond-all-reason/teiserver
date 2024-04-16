defmodule Teiserver.Game.MatchRatingLib do
  @moduledoc """
  This module is used purely for rating calculations, it is not used
  to balance matches. For that use Teiserver.Battle.BalanceLib.
  """

  alias Teiserver.{Account, Coordinator, Config, Game, Battle,}
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Repo
  alias Teiserver.Battle.{BalanceLib, MatchLib}
  require Logger

  @rated_match_types ["Team", "Duel", "FFA", "Team FFA", "Partied Team"]

  @spec rating_type_list() :: [String.t()]
  def rating_type_list() do
    @rated_match_types
  end

  @spec rating_type_id_lookup() :: %{Integer.t() => String.t()}
  def rating_type_id_lookup() do
    rating_type_list()
    |> Map.new(fn name -> {Game.get_or_add_rating_type(name), name} end)
  end

  @spec rating_type_name_lookup() :: %{String.t() => Integer.t()}
  def rating_type_name_lookup() do
    rating_type_list()
    |> Map.new(fn name -> {name, Game.get_or_add_rating_type(name)} end)
  end

  @spec rate_match(non_neg_integer() | Teiserver.Battle.Match.t()) :: :ok | {:error, :no_match}
  def rate_match(match), do: rate_match(match, false)

  @spec rate_match(non_neg_integer() | Teiserver.Battle.Match.t(), boolean()) ::
          :ok | {:error, :no_match}
  def rate_match(match_id, override) when is_integer(match_id) do
    Battle.get_match(match_id, preload: [:members])
    |> rate_match(override)
  end

  def rate_match(nil, _), do: {:error, :no_match}

  def rate_match(match, override) do
    logs = Game.list_rating_logs(search: [match_id: match.id], limit: 1, select: [:id])

    sizes =
      match.members
      |> Enum.group_by(fn m -> m.team_id end)
      |> Enum.map(fn {_, members} -> Enum.count(members) end)
      |> Enum.uniq()

    cheating =
      match.data
      |> Map.get("export_data", %{})
      |> Map.get("cheating", 0)

    cond do
      not Enum.member?(@rated_match_types, match.game_type) ->
        {:error, :invalid_game_type}

      match.processed == false ->
        {:error, :not_processed}

      match.winning_team == nil ->
        {:error, :no_winning_team}

      Enum.count(sizes) != 1 ->
        {:error, :uneven_team_size}

      match.team_count < 2 ->
        {:error, :not_enough_teams}

      match.game_duration < Config.get_site_config_cache("matchmaking.Time to treat game as ranked") ->
        {:error, :too_short}

      Map.get(match.tags, "game/modoptions/ranked_game", "1") == "0" ->
        {:error, :unranked_tag}

      # If override is set to true we skip the next few checks
      override ->
        do_rate_match(match)

      not Enum.empty?(logs) ->
        {:error, :already_rated}

      cheating == 1 ->
        {:error, :cheating_enabled}

      true ->
        do_rate_match(match)
    end
  end

  @spec do_rate_match(Teiserver.Battle.Match.t()) :: :ok
  # The algorithm has not been implemented for FFA correctly so we have a clause for
  # 2 teams (correctly implemented) and a special for 3+ teams
  defp do_rate_match(%{team_count: 2} = match) do
    rating_type_id = Game.get_or_add_rating_type(match.game_type)
    partied_rating_type_id = Game.get_or_add_rating_type("Partied Team")

    # This allows us to handle partied players slightly differently
    # we looked at doing this but there was not enough data. I've
    # left the code commented out because it was such a pain to get
    # working in the first place
    party_ids = []
    # party_ids = match.members
    #   |> Enum.map(fn m -> m.party_id end)
    #   |> Enum.group_by(fn party_id -> party_id end)
    #   |> Map.drop([nil])
    #   |> Enum.map(fn {k, ids} -> {k, Enum.count(ids)} end)
    #   |> Enum.filter(fn {_k, count} -> count >= 2 end)
    #   |> Enum.map(fn {k, _} -> k end)

    winners =
      match.members
      |> Enum.filter(fn membership -> membership.win end)

    losers =
      match.members
      |> Enum.reject(fn membership -> membership.win end)

    partied_user_ids =
      match.members
      |> Enum.filter(fn m -> Enum.member?(party_ids, m.party_id) end)
      |> Enum.map(fn m -> m.user_id end)

    solo_user_ids =
      match.members
      |> Enum.reject(fn m -> Enum.member?(party_ids, m.party_id) end)
      |> Enum.map(fn m -> m.user_id end)

    # We will want to update these so we keep the whole object
    # additionally by using a list_ratings call we avoid the concern
    # of hitting a cache
    solo_rating_lookup =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          user_id_in: solo_user_ids
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    # Now apply a default rating for where there isn't already one
    solo_rating_lookup =
      solo_user_ids
      |> Map.new(fn userid ->
        {userid, solo_rating_lookup[userid] || BalanceLib.default_rating(rating_type_id)}
      end)

    partied_rating_lookup =
      Account.list_ratings(
        search: [
          rating_type_id: partied_rating_type_id,
          user_id_in: partied_user_ids
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    # Partied defaults too
    partied_rating_lookup =
      partied_user_ids
      |> Map.new(fn userid ->
        {userid,
         partied_rating_lookup[userid] || BalanceLib.default_rating(partied_rating_type_id)}
      end)

    rating_lookup = Map.merge(solo_rating_lookup, partied_rating_lookup)

    # Build ratings into lists of tuples for the OpenSkill module to handle
    winner_ratings =
      winners
      |> Enum.map(fn membership ->
        rating = rating_lookup[membership.user_id] || BalanceLib.default_rating(rating_type_id)
        {membership.user_id, {rating.skill, rating.uncertainty}}
      end)

    loser_ratings =
      losers
      |> Enum.map(fn membership ->
        rating = rating_lookup[membership.user_id] || BalanceLib.default_rating(rating_type_id)
        {membership.user_id, {rating.skill, rating.uncertainty}}
      end)

    # Run the actual calculation
    rate_result = rate_with_ids([winner_ratings, loser_ratings], as_map: true)

    status_lookup =
      if match.game_type == "Team" do
        match.members
        |> Map.new(fn membership ->
          {membership.user_id,
           MatchLib.calculate_exit_status(membership.left_after, match.game_duration)}
        end)
      else
        %{}
      end

    # Save the results
    win_ratings =
      winners
      |> Enum.map(fn %{user_id: user_id} ->
        rating_update = rate_result[user_id]
        user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)

        case Map.get(status_lookup, user_id, nil) do
          :abandoned ->
            do_abandoned_rating(user_id, match, user_rating, rating_update)

          :noshow ->
            do_noshow_rating(user_id, match, user_rating, rating_update)

          _ ->
            do_update_rating(user_id, match, user_rating, rating_update)
        end
      end)

    loss_ratings =
      losers
      |> Enum.map(fn %{user_id: user_id} ->
        rating_update = rate_result[user_id]
        user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
        do_update_rating(user_id, match, user_rating, rating_update)
      end)

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Teiserver.Game.RatingLog, win_ratings ++ loss_ratings)
    |> Teiserver.Repo.transaction()

    # Update the match to track rating type
    {:ok, _} = Battle.update_match(match, %{rating_type_id: rating_type_id})

    # If there is a balancer for this match we need to tell it to reset the hashes
    # because there are new values
    case Battle.get_lobby_by_server_uuid(match.server_uuid) do
      nil -> :ok
      %{id: lobby_id} -> Coordinator.cast_balancer(lobby_id, :reset_hashes)
    end

    :ok
  end

  defp do_rate_match(%{team_count: team_count} = match) do
    # When there are more than 2 teams we update the rating as if it was a 2 team game
    # where if you won, the opponent was the best losing team
    # and if you lost the opponent was whoever won

    rating_type_id = Game.get_or_add_rating_type(match.game_type)
    partied_rating_type_id = Game.get_or_add_rating_type("Partied Team")

    # opponent_ratio = 1
    opponent_ratio = 1 / ((team_count - 1) * match.team_size)
    # opponent_ratio = 2/team_count
    # opponent_ratio = 3/(team_count+1)
    # opponent_ratio = 0.5

    # This allows us to handle partied players slightly differently
    # we looked at doing this but there was not enough data. I've
    # left the code commented out because it was such a pain to get
    # working in the first place
    party_ids = []
    # party_ids = match.members
    #   |> Enum.map(fn m -> m.party_id end)
    #   |> Enum.group_by(fn party_id -> party_id end)
    #   |> Map.drop([nil])
    #   |> Enum.map(fn {k, ids} -> {k, Enum.count(ids)} end)
    #   |> Enum.filter(fn {_k, count} -> count >= 2 end)
    #   |> Enum.map(fn {k, _} -> k end)

    winners =
      match.members
      |> Enum.filter(fn membership -> membership.win end)

    losers =
      match.members
      |> Enum.reject(fn membership -> membership.win end)

    partied_user_ids =
      match.members
      |> Enum.filter(fn m -> Enum.member?(party_ids, m.party_id) end)
      |> Enum.map(fn m -> m.user_id end)

    solo_user_ids =
      match.members
      |> Enum.reject(fn m -> Enum.member?(party_ids, m.party_id) end)
      |> Enum.map(fn m -> m.user_id end)

    # We will want to update these so we keep the whole object
    # additionally by using a list_ratings call we avoid the concern
    # of hitting a cache
    solo_rating_lookup =
      Account.list_ratings(
        search: [
          rating_type_id: rating_type_id,
          user_id_in: solo_user_ids
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    # Now apply a default rating for where there isn't already one
    solo_rating_lookup =
      solo_user_ids
      |> Map.new(fn userid ->
        {userid, solo_rating_lookup[userid] || BalanceLib.default_rating(rating_type_id)}
      end)

    partied_rating_lookup =
      Account.list_ratings(
        search: [
          rating_type_id: partied_rating_type_id,
          user_id_in: partied_user_ids
        ]
      )
      |> Map.new(fn rating ->
        {rating.user_id, rating}
      end)

    # Partied defaults too
    partied_rating_lookup =
      partied_user_ids
      |> Map.new(fn userid ->
        {userid,
         partied_rating_lookup[userid] || BalanceLib.default_rating(partied_rating_type_id)}
      end)

    rating_lookup = Map.merge(solo_rating_lookup, partied_rating_lookup)

    # Build ratings into lists of tuples for the OpenSkill module to handle
    winner_ratings =
      winners
      |> Enum.map(fn membership ->
        rating = rating_lookup[membership.user_id] || BalanceLib.default_rating(rating_type_id)
        {membership.user_id, {rating.skill, rating.uncertainty}}
      end)

    # Now we want to get the best loser to use for the winner's win
    loser_ratings =
      losers
      |> Enum.group_by(
        fn %{team_id: team_id} -> team_id end,
        fn %{user_id: user_id} ->
          rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
          {user_id, {rating.skill, rating.uncertainty}}
        end
      )
      |> Map.values()

    # Run the winner calculation
    [win_result | _lose_result] = rate_with_ids([winner_ratings | loser_ratings])
    win_result = Map.new(win_result)

    status_lookup =
      if Enum.member?(["Team", "Team FFA"], match.game_type) do
        match.members
        |> Map.new(fn membership ->
          {membership.user_id,
           MatchLib.calculate_exit_status(membership.left_after, match.game_duration)}
        end)
      else
        %{}
      end

    # Save the results
    win_ratings =
      winners
      |> Enum.map(fn %{user_id: user_id} ->
        rating_update = win_result[user_id]
        user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)

        case Map.get(status_lookup, user_id, nil) do
          :abandoned ->
            do_abandoned_rating(user_id, match, user_rating, rating_update)

          :noshow ->
            do_noshow_rating(user_id, match, user_rating, rating_update)

          _ ->
            do_update_rating(user_id, match, user_rating, rating_update)
        end
      end)

    # If you lose you just count as losing against the winner
    loss_ratings =
      loser_ratings
      |> Enum.map(fn team_ratings ->
        lose_results = rate_with_ids([winner_ratings, team_ratings], as_map: true)

        team_ratings
        |> Enum.map(fn {user_id, _old_rating} ->
          rating_update = lose_results[user_id]

          user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
          ratiod_rating_update = apply_change_ratio(user_rating, rating_update, opponent_ratio)
          do_update_rating(user_id, match, user_rating, ratiod_rating_update)
        end)
      end)
      |> List.flatten()

    # # If you lose we calculate it as last place, there's no such thing as 2nd place
    # loss_ratings = loser_ratings
    #   |> Enum.map(fn team_ratings ->
    #     temp_loser_ratings = loser_ratings
    #       |> List.delete(team_ratings)

    #     lose_results = rate_with_ids([winner_ratings | temp_loser_ratings] ++ [team_ratings], as_map: true)

    #     team_ratings
    #       |> Enum.map(fn {user_id, _old_rating} ->
    #         rating_update = lose_results[user_id]

    #         user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
    #         ratiod_rating_update = apply_change_ratio(user_rating, rating_update, opponent_ratio)
    #         do_update_rating(user_id, match, user_rating, ratiod_rating_update)
    #       end)
    #   end)
    #   |> List.flatten

    # # If you lose we calculate you are 2nd place
    # loss_ratings = loser_ratings
    #   |> Enum.map(fn team_ratings ->
    #     temp_loser_ratings = loser_ratings
    #       |> List.delete(team_ratings)

    #     lose_results = rate_with_ids([winner_ratings, team_ratings] ++ temp_loser_ratings, as_map: true)

    #     team_ratings
    #       |> Enum.map(fn {user_id, _old_rating} ->
    #         rating_update = lose_results[user_id]

    #         user_rating = rating_lookup[user_id] || BalanceLib.default_rating(rating_type_id)
    #         ratiod_rating_update = apply_change_ratio(user_rating, rating_update, opponent_ratio)
    #         do_update_rating(user_id, match, user_rating, ratiod_rating_update)
    #       end)
    #   end)
    #   |> List.flatten

    Ecto.Multi.new()
    |> Ecto.Multi.insert_all(:insert_all, Teiserver.Game.RatingLog, win_ratings ++ loss_ratings)
    |> Teiserver.Repo.transaction()

    # Update the match to track rating type
    {:ok, _} = Battle.update_match(match, %{rating_type_id: rating_type_id})

    # If there is a balancer for this match we need to tell it to reset the hashes
    # because there are new values
    case Battle.get_lobby_by_server_uuid(match.server_uuid) do
      nil -> :ok
      %{id: lobby_id} -> Coordinator.cast_balancer(lobby_id, :reset_hashes)
    end

    :ok
  end

  defp do_rate_match(_), do: :ok

  # Used to ratio the skill lost when there are more than 2 teams
  @spec apply_change_ratio(map(), {number(), number()}, number()) :: {number(), number()}
  defp apply_change_ratio(_user_rating, rating_update, 1.0), do: rating_update

  defp apply_change_ratio(user_rating, rating_update, ratio) do
    {s, u} = rating_update

    skill_change = (user_rating.skill - s) * ratio
    new_skill = user_rating.skill - skill_change

    {new_skill, u}
  end

  defp do_noshow_rating(user_id, match, user_rating, _rating_update) do
    user_rating =
      if Map.get(user_rating, :user_id) do
        user_rating
      else
        {:ok, rating} =
          Account.create_rating(
            Map.merge(user_rating, %{
              user_id: user_id,
              last_updated: match.finished
            })
          )

        rating
      end

    rating_type_id = user_rating.rating_type_id

    %{
      user_id: user_id,
      rating_type_id: rating_type_id,
      match_id: match.id,
      inserted_at: match.finished,
      value: %{
        reason: "No show",
        rating_value: user_rating.rating_value,
        skill: user_rating.skill,
        uncertainty: user_rating.uncertainty,
        rating_value_change: 0,
        skill_change: 0,
        uncertainty_change: 0
      }
    }
  end

  defp do_abandoned_rating(user_id, match, user_rating, _rating_update) do
    user_rating =
      if Map.get(user_rating, :user_id) do
        user_rating
      else
        {:ok, rating} =
          Account.create_rating(
            Map.merge(user_rating, %{
              user_id: user_id,
              last_updated: match.finished
            })
          )

        rating
      end

    rating_type_id = user_rating.rating_type_id

    %{
      user_id: user_id,
      rating_type_id: rating_type_id,
      match_id: match.id,
      inserted_at: match.finished,
      value: %{
        reason: "Abandoned match",
        rating_value: user_rating.rating_value,
        skill: user_rating.skill,
        uncertainty: user_rating.uncertainty,
        rating_value_change: 0,
        skill_change: 0,
        uncertainty_change: 0
      }
    }
  end

  @spec do_update_rating(T.userid(), map(), map(), {number(), number()}) :: any
  defp do_update_rating(user_id, match, user_rating, rating_update) do
    # It's possible they don't yet have a rating
    user_rating =
      if Map.get(user_rating, :user_id) do
        user_rating
      else
        {:ok, rating} =
          Account.create_rating(
            Map.merge(user_rating, %{
              user_id: user_id,
              last_updated: match.finished
            })
          )

        rating
      end

    rating_type_id = user_rating.rating_type_id
    {new_skill, new_uncertainty} = rating_update
    new_rating_value = BalanceLib.calculate_rating_value(new_skill, new_uncertainty)
    new_leaderboard_rating = BalanceLib.calculate_leaderboard_rating(new_skill, new_uncertainty)

    Account.update_rating(user_rating, %{
      rating_value: new_rating_value,
      skill: new_skill,
      uncertainty: new_uncertainty,
      leaderboard_rating: new_leaderboard_rating,
      last_updated: match.finished
    })

    %{
      user_id: user_id,
      rating_type_id: rating_type_id,
      match_id: match.id,
      inserted_at: match.finished,
      value: %{
        rating_value: new_rating_value,
        skill: new_skill,
        uncertainty: new_uncertainty,
        rating_value_change: new_rating_value - user_rating.rating_value,
        skill_change: new_skill - user_rating.skill,
        uncertainty_change: new_uncertainty - user_rating.uncertainty
      }
    }
  end

  @spec reset_player_ratings() :: :ok
  def reset_player_ratings do
    # Delete all ratings and rating logs
    Ecto.Adapters.SQL.query!(Repo, "DELETE FROM teiserver_game_rating_logs", [])
    Ecto.Adapters.SQL.query!(Repo, "DELETE FROM teiserver_account_ratings", [])

    :ok
  end

  @spec reset_player_ratings(Integer.t()) :: :ok
  def reset_player_ratings(rating_type_id) when is_integer(rating_type_id) do
    # Delete all ratings and rating logs
    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM teiserver_game_rating_logs WHERE rating_type_id = $1",
      [rating_type_id]
    )

    Ecto.Adapters.SQL.query!(
      Repo,
      "DELETE FROM teiserver_account_ratings WHERE rating_type_id = $1",
      [rating_type_id]
    )

    :ok
  end

  @spec get_player_rating(T.userid()) :: map
  def get_player_rating(user_id) do
    stats = Account.get_user_stat_data(user_id)

    rating_type_list()
    |> Map.new(fn name ->
      rating_type_id = Game.get_or_add_rating_type(name)

      rating = stats["rating-#{rating_type_id}"]
      rating_value = stats["rating_value-#{rating_type_id}"]
      {name, {rating_value, rating}}
    end)
  end

  @spec re_rate_all_matches :: non_neg_integer()
  def re_rate_all_matches() do
    match_ids =
      Battle.list_matches(
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

  @spec re_rate_all_matches_of_type(String.t()) :: non_neg_integer()
  def re_rate_all_matches_of_type(rating_type_name) do
    match_ids =
      Battle.list_matches(
        search: [
          game_type_in: [rating_type_name],
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

  @spec reset_and_re_rate(String.t()) :: :ok
  def reset_and_re_rate("all") do
    start_time = System.system_time(:millisecond)

    reset_player_ratings()
    match_count = re_rate_all_matches()

    time_taken = System.system_time(:millisecond) - start_time
    Logger.info("re_rate_all_matches, took #{time_taken}ms for #{match_count} matches")
  end

  def reset_and_re_rate(rating_type) do
    start_time = System.system_time(:millisecond)

    rating_type_id = rating_type_name_lookup()[rating_type]

    case rating_type_id do
      nil ->
        Logger.error("No rating type of #{rating_type}")

      _ ->
        reset_player_ratings(rating_type_id)
        match_count = re_rate_all_matches_of_type(rating_type)

        time_taken = System.system_time(:millisecond) - start_time

        Logger.info(
          "re_rate_all_matches_of_type, took #{time_taken}ms for #{match_count} matches"
        )
    end
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
  def predict_winning_team([], _), do: %{winning_team: nil}

  def predict_winning_team(players, rating_type_id) do
    team_scores =
      players
      |> Enum.group_by(
        fn %{team_id: team_id} -> team_id end,
        fn %{user_id: user_id} -> user_id end
      )
      |> Enum.map(fn {team_id, user_ids} ->
        score =
          user_ids
          |> Enum.reduce(0, fn user_id, acc ->
            acc + BalanceLib.get_user_rating_value(user_id, rating_type_id)
          end)

        {team_id, score}
      end)

    winning_team =
      team_scores
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
    rating_type_id = Game.get_or_add_rating_type(match.game_type)
    predict_winning_team(match.members, rating_type_id) |> Map.get(:winning_team)
  end

  def test_predictions() do
    results =
      Battle.list_matches(
        search: [
          # game_type_in: ["Team"],
          game_type_in: @rated_match_types,
          processed: true,
          started_after: Timex.now() |> Timex.shift(days: -31)
        ],
        limit: :infinity,
        preload: [:members]
      )
      |> Enum.reject(fn m -> m.winning_team == nil end)
      |> Enum.map(fn m ->
        prediction = predict_match(m)
        if prediction == m.winning_team, do: 1, else: 0
      end)

    match_count = Enum.count(results)
    correct_count = Enum.sum(results)

    [
      "Checked a total of #{match_count} matches",
      "Correct on #{correct_count} matches (#{correct_count / match_count})"
    ]
    |> Enum.join("\n")
    |> IO.puts()
  end

  # Temporary until we update the OS lib
  def rate_with_ids(rating_groups, options \\ []) do
    rating_groups_without_ids =
      rating_groups
      |> Enum.map(fn ratings_with_ids ->
        ratings_with_ids
        |> Enum.map(fn {_, rating} ->
          rating
        end)
      end)

    result =
      Openskill.rate(rating_groups_without_ids, options)
      |> Enum.zip(rating_groups)
      |> Enum.map(fn {updated_values, original_values} ->
        original_values
        |> Enum.zip(updated_values)
        |> Enum.map(fn {{id, _}, updated_value} ->
          {id, updated_value}
        end)
      end)

    if options[:as_map] do
      result
      |> List.flatten()
      |> Map.new()
    else
      result
    end
  end
end
