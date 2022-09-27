defmodule Central.Repo.Migrations.TrackMatchExitTime do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :game_duration, :integer
    end

    alter table(:teiserver_battle_match_memberships) do
      add :left_after, :integer
    end
  end
end
