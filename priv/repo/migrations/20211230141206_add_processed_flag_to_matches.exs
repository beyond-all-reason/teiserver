defmodule Teiserver.Repo.Migrations.AddProcessedFlagToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :processed, :boolean
    end

    execute "UPDATE teiserver_battle_matches SET processed = true;"
    execute "UPDATE teiserver_battle_matches SET processed = false WHERE data is null;"
  end
end
