defmodule Teiserver.Repo.Migrations.AddPartyChatLog do
  use Ecto.Migration

  def change do
    create table(:teiserver_party_messages) do
      add :content, :text
      add :user_id, references(:account_users, on_delete: :nothing)
      add :party_id, :string
      add :inserted_at, :utc_datetime
    end

    create index(:teiserver_party_messages, [:user_id])
  end
end
