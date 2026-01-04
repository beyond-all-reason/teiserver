defmodule Teiserver.Repo.Migrations.UpdateClanTables do
  use Ecto.Migration

  def change do
    alter table(:teiserver_clans) do
      remove :homepage
    end
  end
end
