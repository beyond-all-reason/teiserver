defmodule Central.Repo.Migrations.AddRatingLogTimestamp do
  use Ecto.Migration

  def change do
    alter table(:teiserver_game_rating_logs) do
      add :inserted_at, :timestamp
    end
  end
end
