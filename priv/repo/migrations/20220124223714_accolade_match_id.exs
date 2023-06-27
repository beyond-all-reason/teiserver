defmodule Teiserver.Repo.Migrations.AccoladeMatchId do
  use Ecto.Migration

  def change do
    alter table(:teiserver_account_accolades) do
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing), null: true
    end

    create index(:teiserver_account_accolades, [:match_id])
  end
end
