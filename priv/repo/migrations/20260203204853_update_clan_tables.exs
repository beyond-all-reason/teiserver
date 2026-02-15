defmodule Teiserver.Repo.Migrations.UpdateClanTables do
  use Ecto.Migration

  def change do
    alter table(:teiserver_clan_invites) do
      remove :response
    end
  end
end
