defmodule Teiserver.Repo.Migrations.AddSeasons do
  use Ecto.Migration

  def change do
    alter table(:teiserver_game_rating_logs) do
      add :season, :integer, default: 1
    end

    alter table(:teiserver_account_ratings) do
      add :season, :integer, default: 1
    end
  end
end
