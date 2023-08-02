defmodule Teiserver.Repo.Migrations.CreateRelationshipsTable do
  use Ecto.Migration

  def change do
    create table(:account_relationships, primary_key: false) do
      add :from_user_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :to_user_id, references(:account_users, on_delete: :nothing, primary_key: true)

      add :state, :string
      add :follow, :boolean, default: false

      add :notes, :string
      add :tags, {:array, :string}

      timestamps()
    end
  end
end
