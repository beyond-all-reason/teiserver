defmodule Central.Repo.Migrations.MatchmakingImprovements do
  use Ecto.Migration

  def change do
    alter table(:teiserver_game_queues) do
      add :team_count, :integer
    end
  end
end
