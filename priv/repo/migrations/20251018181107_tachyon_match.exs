defmodule Teiserver.Repo.Migrations.TachyonMatch do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :matchmaking, :boolean, default: false, null: false
      add :engine_version, :string
      add :game_version, :string
    end
  end
end
