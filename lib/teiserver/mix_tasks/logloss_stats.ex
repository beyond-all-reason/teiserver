defmodule Mix.Tasks.Teiserver.LoglossStats do
  @moduledoc """
  The purpose of this task is to get statistics on how well we predict the winner of a match. We use the Logloss score to measure prediction accuracy
  Logloss formula: https://www.dratings.com/log-loss-vs-brier-score/

  To run:

  mix teiserver.logloss_stats
  """

  use Mix.Task
  require Logger
  alias Teiserver.Repo
  alias Teiserver.{Battle, Game}
  alias Teiserver.Battle.{BalanceLib}
  alias Mix.Tasks.Teiserver.PartyBalanceStatsTypes, as: PB
  alias Teiserver.Config

  @noob_matches_cutoff 20
  @num_matches_to_process 2000

  @rating_systems [:openskill, :bar, :provisional_5, :provisional_10, :provisional_20]

  def run(args) do
    Logger.info("Args: #{args}")
    {min_team_size, _} = Integer.parse(Enum.at(args, 0, "8"))

    Application.ensure_all_started(:teiserver)
    opts = []

    match_ids = get_match_ids(min_team_size)

    initial_errors = %{
      noob_matches: %{
        errors: [],
        num_matches: 0
      },
      experienced_matches: %{
        errors: [],
        num_matches: 0
      }
    }

    # The error result will be the sum of forecast errors for all matches
    error_result =
      Enum.map(match_ids, fn match_id -> get_match_log_loss(match_id) end)
      |> Enum.reduce(initial_errors, fn match_error, acc ->
        if(match_error.invalid_match?) do
          # Do not process
          acc
        else
          key = if match_error.has_noobs?, do: :noob_matches, else: :experienced_matches

          # We simply add the errors for each match
          updated_errors = %{
            errors: match_error.errors ++ acc[key].errors,
            num_matches: acc[key].num_matches + 1
          }

          Map.put(acc, key, updated_errors)
        end
      end)

    # The log_loss_score formula is explained here: https://www.dratings.com/log-loss-vs-brier-score/
    log_loss_score = %{
      noob_matches: convert_error_result_to_log_loss_score(error_result.noob_matches),
      experienced_matches:
        convert_error_result_to_log_loss_score(error_result.experienced_matches)
    }

    IO.inspect(log_loss_score, label: "log_loss_score", charlists: :as_lists)
    Logger.info("Finished processing matches")
  end

  defp convert_error_result_to_log_loss_score(error_result) do
    Enum.map(@rating_systems, fn rating_system ->
      errors =
        error_result.errors
        |> Enum.filter(fn x -> x.rating_system == rating_system end)

      error_sum =
        errors
        |> Enum.reduce(0, fn x, acc -> x.forecast_error + acc end)

      num_matches = max(1, Enum.count(errors))
      log_loss_score = -error_sum / num_matches

      %{
        rating_system: rating_system,
        log_loss_score: log_loss_score,
        num_matches: num_matches
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

  # This will return [y*log(p) + (1-y)*log(1-p)]
  defp get_match_log_loss(match_id) do
    # This query will return players of this match
    # Sorted by win desc so that team 1 will always be the winning team
    # All log data is the postmatch value so we need to make adjustments to get prematch values
    query = """
    select team_id, win,
    (value->'skill')::float - (value->'skill_change')::float   as skill,
    (value->'uncertainty')::float - (value->'uncertainty_change')::float   as uncertainty,

    (value->'num_matches')::int - 1  as num_matches
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
      |> Enum.map(fn [team_id, win, skill, uncertainty, num_matches] ->
        %{
          team_id: team_id,
          win: win,
          skill: skill,
          uncertainty: uncertainty,
          num_matches: num_matches
        }
      end)

    teams =
      players
      |> Enum.group_by(fn x -> x.team_id end)

    invalid_match? = players |> Enum.any?(fn x -> x.num_matches == nil || x.skill > 100 end)

    if(invalid_match?) do
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
            forecast_error: process_sql_result(teams, rating_system)
          }
        end)

      %{
        errors: errors,
        has_noobs?: has_noobs?,
        invalid_match?: false
      }
    end
  end

  # Teams are a list of players
  # First team is always the winning team
  # Returns the forecast error squared
  defp process_sql_result(teams, rating_system) do
    openskill_teams =
      teams |> Enum.map(fn {x, v} -> convert_player_list_to_tuple_list(v, rating_system) end)

    # When predicting, we should feed into the openskill library the {skill, uncertainty} of players
    # However, since we balance on player rating, instead we feed in {rating, uncertainty} of all players

    [team1_win_predict, _team2_win_predict] = Openskill.predict_win(openskill_teams)
    # team 1 is the winning team
    get_forecast_error(team1_win_predict)
  end

  # Fully accurate forecast will be 0.
  # Lower is better
  defp get_forecast_error(winning_team_predict) do
    :math.log(winning_team_predict)
  end

  # Converts a list of player maps into tuples to be fed into OpenSkill library win_predict function
  defp convert_player_list_to_tuple_list(player_list, rating_system) do
    player_list |> Enum.map(fn x -> {get_rating(x, rating_system), x.uncertainty} end)
  end

  defp get_rating(player, rating_system) do
    num_matches = player.num_matches || 0

    case rating_system do
      :openskill ->
        player.skill

      :bar ->
        max(player.skill - player.uncertainty, 0)

      :provisional_20 ->
        min(num_matches / 20, 1) * (player.skill - player.uncertainty)

      :provisional_10 ->
        min(num_matches / 10, 1) * (player.skill - player.uncertainty)

      :provisional_5 ->
        min(num_matches / 5, 1) * (player.skill - player.uncertainty)
    end
  end
end
