defmodule Teiserver.Repo.Migrations.TeiserverUserStats do
  use Ecto.Migration

  def change do
    create table(:teiserver_account_user_stats, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :data, :jsonb
    end
  end
end
