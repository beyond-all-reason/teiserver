defmodule Teiserver.Repo.Migrations.AddPlayercountToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :player_count, :integer
    end
  end
end
