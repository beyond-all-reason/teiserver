defmodule Central.Repo.Migrations.AddTypeToSmurfKeys do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_smurf_key_types) do
      add :name, :string
    end

    alter table(:teiserver_account_smurf_keys) do
      add :type_id, references(:teiserver_account_smurf_key_types, on_delete: :nothing)
    end
    drop index(:teiserver_account_smurf_keys, [:value])
    create index(:teiserver_account_smurf_keys, [:user_id])
  end
end
