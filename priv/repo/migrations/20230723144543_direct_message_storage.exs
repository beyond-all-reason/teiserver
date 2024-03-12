defmodule Barserver.Repo.Migrations.DirectMessageStorage do
  use Ecto.Migration

  def change do
    create table(:direct_messages) do
      add :from_id, references(:account_users, on_delete: :nothing)
      add :to_id, references(:account_users, on_delete: :nothing)
      add :inserted_at, :utc_datetime
      add :content, :text
    end
  end
end
