defmodule Teiserver.Repo.Migrations.AddLeaderboardRatingToRatingsTable do
  use Ecto.Migration

  def change do
    alter table(:teiserver_account_ratings) do
      add :leaderboard_rating, :float
    end

    execute "UPDATE teiserver_account_ratings SET leaderboard_rating = skill - (3 * uncertainty);"
  end
end
