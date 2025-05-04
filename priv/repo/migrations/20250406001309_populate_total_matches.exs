defmodule Teiserver.Repo.Migrations.PopulateTotalMatches do
  use Ecto.Migration

  def change do
    # Populate total_matches for season 1 and 2
    seasons = [1, 2]

    Enum.each(seasons, fn season_number ->
      execute(populate_query(season_number), "")
    end)
  end

  def populate_query(season_number) do
    """
    update teiserver_account_ratings tar
    set total_matches = temp_table.total_matches,
    total_wins = temp_table.total_wins
    from (
    select user_id, rating_type_id, sum(num_matches) as total_matches, sum(num_wins) as total_wins  from teiserver_account_ratings tar
    where season <= #{season_number}
    group by user_id, rating_type_id
    ) as temp_table
    where tar.user_id = temp_table.user_id
    and tar.rating_type_id = temp_table.rating_type_id
    and tar.season = #{season_number}
    """
  end
end
