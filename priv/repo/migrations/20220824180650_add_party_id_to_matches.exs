defmodule Teiserver.Repo.Migrations.AddPartyIdToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_match_memberships) do
      add :party_id, :string
    end
  end
end
