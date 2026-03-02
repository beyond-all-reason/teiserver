defmodule Teiserver.Repo.Migrations.UpdateClanTables do
  use Ecto.Migration

  def change do
    alter table(:teiserver_clans) do
      add :language, :string
    end
  end
end
