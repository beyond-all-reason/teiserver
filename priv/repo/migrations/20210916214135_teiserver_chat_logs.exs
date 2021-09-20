defmodule Central.Repo.Migrations.TeiserverChatLogs do
  use Ecto.Migration

  def change do
    create table(:teiserver_room_messages) do
      add :content, :text
      add :user_id, references(:account_users, on_delete: :nothing)
      add :chat_room, :string
      add :inserted_at, :utc_datetime
    end
    create index(:teiserver_room_messages, [:user_id])

    create table(:teiserver_lobby_messages) do
      add :content, :text
      add :user_id, references(:account_users, on_delete: :nothing)
      add :lobby_guid, :string
      add :inserted_at, :utc_datetime
    end
    create index(:teiserver_lobby_messages, [:user_id])
  end
end
