defmodule Teiserver.Repo.Migrations.AddNumMatchesColumn do
  use Ecto.Migration

  def change do
    alter table("teiserver_account_ratings") do
      add :num_matches, :integer
    end

    # Populate num_matches column
    up_query = """
    UPDATE teiserver_account_ratings  SET num_matches  = temp_table.count
    FROM (SELECT user_id, rating_type_id , count(*) from teiserver_game_rating_logs tgrl
    where match_id  is not null
    group by user_id , rating_type_id  ) AS temp_table
    WHERE teiserver_account_ratings.user_id = temp_table.user_id
    and teiserver_account_ratings.rating_type_id  = temp_table.rating_type_id
    """

    # If we rollback we don't have to do anything
    rollback_query = ""

    execute(up_query, rollback_query)
  end
end
