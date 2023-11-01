defmodule Teiserver.Repo.Migrations.CreateConfigTables do
  use Ecto.Migration

  def change do
    create table(:config_user) do
      add :key, :string
      add :value, :string
      add :user_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end

    create index(:config_user, [:user_id])

    create table(:config_site, primary_key: false) do
      add :key, :string, primary_key: true
      add :value, :string

      timestamps()
    end
  end
end
