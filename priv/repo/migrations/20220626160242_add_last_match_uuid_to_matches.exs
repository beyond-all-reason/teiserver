defmodule Teiserver.Repo.Migrations.AddLastMatchUuidToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :last_match_uuid, :string
    end
  end
end
