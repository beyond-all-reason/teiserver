defmodule Mix.Tasks.Teiserver.SeasonalUncertaintyResetTask do
  @moduledoc """
  Run with
    mix teiserver.seasonal_uncertainty_reset_task
  If you want to specify the uncertainty target use
    mix teiserver.seasonal_uncertainty_reset_task 5
  where 5 is the uncertainty target
  """

  use Mix.Task

  require Logger

  @spec run(list()) :: :ok
  def run(args) do
    Logger.info("Args: #{args}")
    default_uncertainty_target = "5"
    {uncertainty_target, _} = Enum.at(args, 0, default_uncertainty_target) |> Float.parse()

    Application.ensure_all_started(:teiserver)

    start_time = System.system_time(:millisecond)

    sql_transaction_result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:create_temp_table, fn repo, _ ->
        query = """
        CREATE temp table temp_table as
        SELECT
          *,
          greatest(0, skill - new_uncertainty) as new_rating,
          new_uncertainty - uncertainty as uncertainty_change,
          greatest(0, skill - new_uncertainty)- rating_value as rating_value_change,
          skill - 3 * new_uncertainty as new_leaderboard_rating
        FROM
        (
        SELECT
          user_id,
          rating_type_id,
          rating_value,
          uncertainty,
          calculate_season_uncertainty(uncertainty, last_updated, $1) as new_uncertainty,
          skill,
          num_matches
        FROM
          teiserver_account_ratings tar
        ) as a;
        """

        Ecto.Adapters.SQL.query(repo, query, [uncertainty_target])
      end)
      |> Ecto.Multi.run(:add_logs, fn repo, _ ->
        query = """
        INSERT INTO teiserver_game_rating_logs (inserted_at, rating_type_id, user_id, value)
        SELECT
        now(),
        rating_type_id,
        user_id,
        JSON_BUILD_OBJECT(
          'skill', skill,
          'reason', 'Uncertainty minimum override',
          'uncertainty', new_uncertainty,
          'rating_value', new_rating,
          'skill_change', 0.0,
          'uncertainty_change', uncertainty_change,
          'rating_value_change', rating_value_change,
          'num_matches', num_matches
        )
        FROM temp_table;
        """

        Ecto.Adapters.SQL.query(repo, query, [])
      end)
      |> Ecto.Multi.run(:update_ratings, fn repo, _ ->
        query = """
        UPDATE teiserver_account_ratings tar
        SET
          uncertainty = t.new_uncertainty,
          rating_value = t.new_rating,
          leaderboard_rating  = t.new_leaderboard_rating
        FROM temp_table t
        WHERE t.user_id = tar.user_id
          and t.rating_type_id = tar.rating_type_id;
        """

        Ecto.Adapters.SQL.query(repo, query, [])
      end)
      |> Teiserver.Repo.transaction()

    # credo:disable-for-next-line Credo.Check.Readability.WithSingleClause
    with {:ok, result} <- sql_transaction_result do
      time_taken = System.system_time(:millisecond) - start_time

      Logger.info(
        "SeasonalUncertaintyResetTask complete, took #{time_taken}ms. Updated #{result.update_ratings.num_rows} ratings."
      )
    else
      _ ->
        Logger.error("SeasonalUncertaintyResetTask failed.")
    end
  end
end
