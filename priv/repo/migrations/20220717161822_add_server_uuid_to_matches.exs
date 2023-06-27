defmodule Teiserver.Repo.Migrations.AddServerUuidToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      remove :last_match_uuid, :string
      add :server_uuid, :string
    end
  end
end
