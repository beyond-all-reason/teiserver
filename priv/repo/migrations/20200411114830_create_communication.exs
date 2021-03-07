defmodule Central.Repo.Migrations.CreateCommunication.Chat do
  use Ecto.Migration

  def change do
    create table(:communication_notifications) do
      add :user_id, references(:account_users, on_delete: :nothing)

      add :title, :string
      add :body, :string
      add :icon, :string
      add :colour, :string
      add :redirect, :string

      add :read, :boolean, default: false, null: false
      add :expires, :utc_datetime
      add :expired, :boolean, default: false, null: false

      timestamps()
    end

    create index(:communication_notifications, [:user_id])

    create table(:communication_chat_rooms) do
      add :name, :string
      add :description, :text

      add :colour, :string
      add :icon, :string

      add :current_content, :integer
      add :public, :boolean
      add :rules, :jsonb

      timestamps()
    end

    create index(:communication_chat_rooms, [:name])

    create table(:communication_chat_contents) do
      add :content, :text
      add :metadata, :jsonb
      add :user_id, references(:account_users, on_delete: :nothing)
      add :chat_room_id, references(:communication_chat_rooms, on_delete: :nothing)

      timestamps()
    end

    create table(:communication_chat_memberships, primary_key: false) do
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true

      add :chat_room_id, references(:communication_chat_rooms, on_delete: :nothing),
        primary_key: true

      add :role, :string
      add :last_seen, :utc_datetime

      timestamps()
    end

    create table(:communication_chat_responses) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :chat_content_id, references(:communication_chat_contents, on_delete: :nothing)

      add :content, :string

      timestamps()
    end
  end
end
