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
  end
end
