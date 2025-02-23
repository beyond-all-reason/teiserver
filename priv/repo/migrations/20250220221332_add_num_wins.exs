defmodule Teiserver.Repo.Migrations.AddNumWins do
  use Ecto.Migration

  def change do
    alter table("teiserver_account_ratings") do
      add :num_wins, :integer, default: 0
    end

    # Populate num_wins column
    up_query = """
    UPDATE teiserver_account_ratings  SET num_wins  = temp_table.num_wins
    FROM (SELECT tgrl.user_id, rating_type_id, count(*) as num_wins   from teiserver_game_rating_logs tgrl
    inner join teiserver_battle_match_memberships tbmm
    on tbmm.match_id = tgrl.match_id
    and tbmm.user_id  = tgrl.user_id
    and tbmm.match_id  is not null
    and win = true
    group by tgrl.user_id, rating_type_id) AS temp_table
    WHERE teiserver_account_ratings.user_id = temp_table.user_id
    and teiserver_account_ratings.rating_type_id  = temp_table.rating_type_id
    """

    # If we rollback we don't have to do anything
    rollback_query = ""

    execute(up_query, rollback_query)
  end
end
