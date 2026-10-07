defmodule Teiserver.Repo.Migrations.UniqueIndexRatingLogs do
  use Ecto.Migration

  def up do
    # Remove duplicate entries keeping the earliest
    # (lowest id) per (match_id, user_id, rating_type_id)
    execute("""
    DELETE FROM teiserver_game_rating_logs
    WHERE id NOT IN (
      SELECT DISTINCT ON (match_id, user_id, rating_type_id) id
      FROM teiserver_game_rating_logs
      ORDER BY match_id, user_id, rating_type_id, id ASC
    )
    """)

    create unique_index(:teiserver_game_rating_logs, [:match_id, :user_id, :rating_type_id])
  end

  def down do
    drop unique_index(:teiserver_game_rating_logs, [:match_id, :user_id, :rating_type_id])
  end
end
