defmodule Barserver.Repo.Migrations.AddServerEvents do
  use Ecto.Migration

  def change do
    create table(:telemetry_server_event_types) do
      add :name, :string
    end

    create table(:teiserver_telemetry_server_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :timestamp, :utc_datetime

      add :event_type_id, references(:telemetry_server_event_types, on_delete: :nothing)
      add :value, :jsonb
    end
  end
end
