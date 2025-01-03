defmodule Mix.Tasks.Teiserver.ProvisionalRatingSetup do
  @moduledoc """
  Running this task will change the rating system to one where new players start at zero,
  then converge towards their skill over time.
  The rating formula:
  least(1, num_matches/30) * skill
  30 is the target number of matches for your rating to just equal to skill.
  This number is adjustable on the admin site config page.

  To use this new rating system run:
  mix teiserver.provisional_rating_setup

  To rollback use:
  mix teiserver.provisional_rating_setup -rollback
  """

  use Mix.Task
  require Logger
  alias Teiserver.Config
  alias Teiserver.Battle.BalanceLib

  def run(args) do
    Application.ensure_all_started(:teiserver)

    rollback? = Enum.member?(args, "-rollback")
    target_matches = BalanceLib.get_num_matches_for_rating_to_equal_skill()

    sql_transaction_result =
      Ecto.Multi.new()
      |> Ecto.Multi.run(:create_temp_table, fn repo, _ ->
        {query, params} =
          case rollback? do
            false ->
              {"""
               CREATE temp table temp_table as
               SELECT
                 *,
                 least(1, cast(num_matches as decimal) / $1) * skill as new_rating
               FROM
                 teiserver_account_ratings tar;
               """, [target_matches]}

            true ->
              {"""
               CREATE temp table temp_table as
               SELECT
                 *,
                 greatest(0,skill-uncertainty ) as new_rating
               FROM
                 teiserver_account_ratings tar;
               """, []}
          end

        Ecto.Adapters.SQL.query(repo, query, params)
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
          'reason', 'New rating system',
          'uncertainty', uncertainty,
          'rating_value', new_rating,
          'skill_change', 0.0,
          'uncertainty_change', 0.0,
          'rating_value_change', t.new_rating - t.rating_value,
          'num_matches', num_matches
        )
        FROM temp_table t;
        """

        Ecto.Adapters.SQL.query(repo, query, [])
      end)
      |> Ecto.Multi.run(:update_ratings, fn repo, _ ->
        query = """
        UPDATE teiserver_account_ratings tar
        SET
          rating_value = t.new_rating,
          last_updated = now()
         FROM temp_table t
        WHERE t.user_id = tar.user_id
          and t.rating_type_id = tar.rating_type_id;

        """

        Ecto.Adapters.SQL.query(repo, query, [])
      end)
      |> Teiserver.Repo.transaction()

    with {:ok, _result} <- sql_transaction_result do
      case rollback? do
        true ->
          Logger.info("Rollback to old rating system complete")

          # This config is not viewable in the admin page as we don't want someone to manually change it.
          # To change it use this mix task
          Config.update_site_config("hidden.Rating method", "skill minus uncertainty")

        false ->
          Logger.info("New rating system change complete")
          Config.update_site_config("hidden.Rating method", "start at zero; converge to skill")
      end
    else
      _ ->
        Logger.error("Task failed.")
    end
  end
end
