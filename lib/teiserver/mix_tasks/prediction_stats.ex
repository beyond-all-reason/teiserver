defmodule Mix.Tasks.Teiserver.PredictionStats do
  @moduledoc """
  The purpose of this task is to get statistics on how well we predict the winner of a match. We use the Logloss score to measure prediction accuracy
  Logloss formula: https://www.dratings.com/log-loss-vs-brier-score/

  To run:

  mix teiserver.prediction_stats
  mix teiserver.prediction_stats --doublecaptain
  """

  use Mix.Task
  require Logger
  alias Teiserver.Repo

  @noob_matches_cutoff 50
  @num_matches_to_process 2000

  @rating_systems [
    :openskill,
    :bar,
    :bar_negative,
    :leaderboard_2,
    :leaderboard_3,
    :provisional_5,
    :provisional_10,
    :provisional_20,
    :provisional_30,
    :provisional_50
  ]

  def run(args) do
    {opts, _, _} =
      OptionParser.parse(args,
        strict: [
          debug: :boolean,
          brier: :boolean,
          logloss: :boolean,
          doublecaptain: :boolean,
          offset: :integer
        ]
      )

    min_team_size =
      case Keyword.get(opts, :debug, false) do
        true -> 2
        false -> 8
      end

    Application.ensure_all_started(:teiserver)

    match_ids = get_match_ids(min_team_size)

    initial_errors = %{
      noob_matches: %{
        errors: [],
        num_matches: 0,
        matches_with_win_data: 0
      },
      experienced_matches: %{
        errors: [],
        num_matches: 0,
        matches_with_win_data: 0
      }
    }

    # The error result will be the sum of forecast errors for all matches
    error_result =
      Enum.map(match_ids, fn match_id -> get_match_error(match_id, opts) end)
      |> Enum.reduce(initial_errors, fn match_error, acc ->
        if(match_error.invalid_match?) do
          # Do not process
          acc
        else
          key = if match_error.has_noobs?, do: :noob_matches, else: :experienced_matches
          win_data_increment = if match_error.has_win_data?, do: 1, else: 0

          # We simply add the errors for each match
          updated_errors = %{
            errors: match_error.errors ++ acc[key].errors,
            num_matches: acc[key].num_matches + 1,
            matches_with_win_data: acc[key].matches_with_win_data + win_data_increment
          }

          Map.put(acc, key, updated_errors)
        end
      end)

    # The score formula is explained here: https://www.dratings.com/log-loss-vs-brier-score/
    score = %{
      noob_matches: convert_error_result_to_score(error_result.noob_matches),
      experienced_matches: convert_error_result_to_score(error_result.experienced_matches)
    }

    IO.inspect(opts, label: "opts", charlists: :as_lists)

    IO.inspect(score, label: "score", charlists: :as_lists)
    Logger.info("Finished processing matches")
  end

  defp convert_error_result_to_score(error_result) do
    Enum.map(@rating_systems, fn rating_system ->
      errors =
        error_result.errors
        |> Enum.filter(fn x -> x.rating_system == rating_system end)

      error_sum =
        errors
        |> Enum.reduce(0, fn x, acc -> x.forecast_error + acc end)

      num_matches = error_result.num_matches
      score = error_sum / max(1, num_matches)
      matches_with_win_data = error_result.matches_with_win_data

      %{
        rating_system: rating_system,
        score: score,
        num_matches: num_matches,
        matches_with_win_data: matches_with_win_data
      }
    end)
  end

  defp get_match_ids(min_team_size) do
    query = """
    select distinct  tbm.id, tbm.inserted_at  from
    teiserver_battle_matches tbm
    inner join teiserver_game_rating_logs tgrl
    on tgrl.match_id = tbm.id
    and tbm.team_size >= $1
    and tbm.team_size <= 8
    and tbm.team_count = $2
    and tgrl.value is not null
    and tgrl.season = 1
    order by tbm.inserted_at DESC
    limit $3;

    """

    team_count = 2

    sql_results =
      Ecto.Adapters.SQL.query!(Repo, query, [min_team_size, team_count, @num_matches_to_process])

    sql_results.rows
    |> Enum.map(fn [id, _inserted] ->
      id
    end)
  end

  defp get_match_error(match_id, opts) do
    # This query will return players of this match
    # Sorted by win desc so that team 1 will always be the winning team
    # All log data is the postmatch value so we need to make adjustments to get prematch values
    query = """
    select team_id, win,
    (value->'skill')::float - (value->'skill_change')::float   as skill,
    (value->'uncertainty')::float - (value->'uncertainty_change')::float   as uncertainty,

    (value->'num_matches')::int - 1  as num_matches,
    CASE
      WHEN win THEN (value->'num_wins')::int - 1
    ELSE
      (value->'num_wins')::int
    END as "num_wins"
    from teiserver_game_rating_logs tgrl
    inner join teiserver_battle_match_memberships tbmm
    on tbmm.match_id = tgrl.match_id
    and tbmm.match_id  = $1
    and tbmm.user_id  = tgrl.user_id
    order by win desc
    """

    sql_results = Ecto.Adapters.SQL.query!(Repo, query, [match_id])

    players =
      sql_results.rows
      |> Enum.map(fn [team_id, win, skill, uncertainty, num_matches, num_wins] ->
        %{
          team_id: team_id,
          win: win,
          skill: skill,
          uncertainty: uncertainty,
          num_matches: num_matches,
          num_wins: num_wins
        }
      end)

    teams =
      players
      |> Enum.group_by(fn x -> x.team_id end)

    invalid_match? = players |> Enum.any?(fn x -> x.num_matches == nil || x.skill > 100 end)
    debug? = Keyword.get(opts, :debug, false)
    has_win_data? = players |> Enum.any?(fn x -> x.num_wins != nil end)

    if(invalid_match? && !debug?) do
      %{
        invalid_match?: true
      }
    else
      has_noobs? =
        players |> Enum.any?(fn x -> x.num_matches < @noob_matches_cutoff end)

      errors =
        Enum.map(@rating_systems, fn rating_system ->
          %{
            rating_system: rating_system,
            forecast_error: process_sql_result(teams, rating_system, opts)
          }
        end)

      %{
        errors: errors,
        has_noobs?: has_noobs?,
        invalid_match?: false,
        has_win_data?: has_win_data?
      }
    end
  end

  # Teams are a list of players
  # First team is always the winning team
  # Returns the forecast error squared
  defp process_sql_result(teams, rating_system, opts) do
    openskill_teams =
      teams
      |> Enum.map(fn {_key, v} -> convert_player_list_to_tuple_list(v, rating_system, opts) end)

    openskill_teams =
      if Keyword.get(opts, :doublecaptain, false) do
        openskill_teams |> double_captain
      else
        openskill_teams
      end

    # This will be [true,false] if first team is winner. Otherwise will be [false,true]
    win_list = teams |> Enum.map(fn {_key, value} -> Enum.at(value, 0).win end)

    # When predicting, we should feed into the openskill library the {skill, uncertainty} of players
    # However, since we balance on player rating, instead we feed in {rating, uncertainty} of all players
    [team1_win_predict, team2_win_predict] = Openskill.predict_win(openskill_teams)

    win_predict =
      case Enum.at(win_list, 0) do
        # team 1 is the winning team
        true -> team1_win_predict
        # team 2 is the winning team
        false -> team2_win_predict
      end

    get_forecast_error(win_predict, opts)
  end

  # Treat each team as if they have a clone of the captain
  defp double_captain(openskill_teams) do
    Enum.map(openskill_teams, fn team ->
      captain = Enum.max_by(team, fn {skill, _uncertainty} -> skill end)
      [captain | team]
    end)
  end

  # Fully accurate forecast will be 0.
  # Lower is better
  defp get_forecast_error(winning_team_predict, opts) do
    cond do
      # Get error using logloss
      Keyword.get(opts, :logloss, false) -> -:math.log(winning_team_predict)
      # Get error using Brier
      true -> (1 - winning_team_predict) ** 2
    end
  end

  # Converts a list of player maps into tuples to be fed into OpenSkill library win_predict function
  defp convert_player_list_to_tuple_list(player_list, rating_system, opts) do
    player_list |> Enum.map(fn x -> {get_rating(x, rating_system, opts), x.uncertainty} end)
  end

  defp get_rating(player, rating_system, opts) do
    num_matches = player.num_matches || 0
    offset = Keyword.get(opts, :offset, 0)

    case rating_system do
      :openskill ->
        player.skill

      :bar ->
        max(player.skill - player.uncertainty, 0)

      :bar_negative ->
        player.skill - player.uncertainity

      :leaderboard_2 ->
        player.skill - player.uncertainity * 2

      :leaderboard_3 ->
        player.skill - player.uncertainity * 3

      :provisional_50 ->
        min(num_matches / 50, 1) * (player.skill - player.uncertainty + offset)

      :provisional_30 ->
        min(num_matches / 30, 1) * (player.skill - player.uncertainty + offset)

      :provisional_20 ->
        min(num_matches / 20, 1) * (player.skill - player.uncertainty + offset)

      :provisional_10 ->
        min(num_matches / 10, 1) * (player.skill - player.uncertainty + offset)

      :provisional_5 ->
        min(num_matches / 5, 1) * (player.skill - player.uncertainty + offset)
    end
  end
end
