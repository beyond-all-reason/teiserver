defmodule Central.Repo.Migrations.AddPartyIdToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_account_ratings) do
      add :party_id, :string
    end

    alter table(:teiserver_battle_match_memberships) do
      add :party_id, :string
    end
  end
end
