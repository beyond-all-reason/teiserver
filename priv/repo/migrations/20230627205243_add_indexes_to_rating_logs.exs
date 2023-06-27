defmodule Teiserver.Repo.Migrations.Testtesttest do
  use Ecto.Migration

  def change do
    create index(:teiserver_game_rating_logs, [:user_id])
    create index(:teiserver_game_rating_logs, [:match_id])
  end
end
