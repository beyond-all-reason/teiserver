defmodule Central.Repo.Migrations.IngameTelemetry do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_game_event_types) do
      add :name, :string
    end

    create table(:teiserver_telemetry_unauth_game_events) do
      add :hash, :string
      add :timestamp, :utc_datetime

      add :game_event_type_id, references(:teiserver_telemetry_game_event_types, on_delete: :nothing)
      add :value, :jsonb
    end

    create table(:teiserver_telemetry_client_game_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :timestamp, :utc_datetime

      add :game_event_type_id, references(:teiserver_telemetry_game_event_types, on_delete: :nothing)
      add :value, :jsonb
    end
  end
end
