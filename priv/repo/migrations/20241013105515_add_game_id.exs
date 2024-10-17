defmodule Teiserver.Repo.Migrations.AddGameId do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :game_id, :string
    end
  end
end
