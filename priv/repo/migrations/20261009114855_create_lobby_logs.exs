defmodule Teiserver.Repo.Migrations.CreateLobbyLogs do
  use Ecto.Migration

  def change do
    create table(:lobby_logs) do
      add :lobby_id, :uuid, null: false
      add :event_type, :text, null: false
      add :user_id, references(:account_users, on_delete: :delete_all)
      add :target_id, references(:account_users, on_delete: :delete_all)
      add :details, :map

      timestamps(updated_at: false, type: :utc_datetime_usec)
    end

    create index(:lobby_logs, [:event_type])
    create index(:lobby_logs, [:inserted_at])
  end
end
