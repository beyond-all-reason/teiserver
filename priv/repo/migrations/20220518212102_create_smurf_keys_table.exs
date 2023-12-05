defmodule Teiserver.Repo.Migrations.CreateSmurfKeysTable do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_smurf_key_types) do
      add :name, :string
    end

    create table(:teiserver_account_smurf_keys) do
      add :value, :string
      add :user_id, references(:account_users, on_delete: :nothing)
      add :type_id, references(:teiserver_account_smurf_key_types, on_delete: :nothing)
      add :last_updated, :timestamp
    end

    create index(:teiserver_account_smurf_keys, [:user_id])
  end
end
