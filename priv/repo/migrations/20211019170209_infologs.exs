defmodule Barserver.Repo.Migrations.Infologs do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_infologs) do
      add :user_hash, :string
      add :user_id, references(:account_users, on_delete: :nothing)
      add :timestamp, :utc_datetime

      add :log_type, :string
      add :metadata, :jsonb
      add :contents, :text
      add :size, :integer
    end
  end
end
