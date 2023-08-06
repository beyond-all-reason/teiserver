defmodule Teiserver.Repo.Migrations.CreateRelationshipsTable do
  use Ecto.Migration

  def change do
    create table(:account_relationships, primary_key: false) do
      add :from_user_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :to_user_id, references(:account_users, on_delete: :nothing, primary_key: true)

      add :state, :string

      add :notes, :string
      add :tags, {:array, :string}

      timestamps()
    end

    create table(:account_friends, primary_key: false) do
      add :user1_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :user2_id, references(:account_users, on_delete: :nothing, primary_key: true)

      timestamps()
    end

    create table(:account_friend_requests, primary_key: false) do
      add :from_user_id, references(:account_users, on_delete: :nothing, primary_key: true)
      add :to_user_id, references(:account_users, on_delete: :nothing, primary_key: true)

      timestamps()
    end
  end
end
