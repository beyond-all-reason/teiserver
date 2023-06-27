defmodule Teiserver.Repo.Migrations.CreateSmurfKeysTable do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_smurf_keys) do
      add :value, :string
      add :user_id, references(:account_users, on_delete: :nothing)
    end

    create index(:teiserver_account_smurf_keys, [:value])
  end
end
