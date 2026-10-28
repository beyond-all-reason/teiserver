defmodule Teiserver.Repo.Migrations.AddAntiAbuseRecord do
  use Ecto.Migration

  def change do
    create_if_not_exists table(:moderation_anti_abuse_records, primary_key: false) do
      add :id, :uuid, primary_key: true, null: false

      add :user_id, references(:account_users, on_delete: :nothing), null: false
      add :expires_at, :utc_datetime, null: false
      add :clean, :boolean, null: false
      add :hashes, :jsonb, null: false
      add :notes, :text

      add :restored_at, :utc_datetime
      add :restored_by_id, references(:account_users, on_delete: :nothing)

      timestamps()
    end
  end
end
