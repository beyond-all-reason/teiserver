defmodule Teiserver.Repo.Migrations.SimpleAndComplexEvents do
  use Ecto.Migration

  def change do
    # Rename a bunch of tables to have consistent naming conventions
    execute "ALTER TABLE telemetry_client_event_types RENAME TO telemetry_complex_client_event_types"

    execute "ALTER TABLE teiserver_telemetry_client_events RENAME TO telemetry_complex_client_events"

    execute "ALTER TABLE teiserver_telemetry_property_types RENAME TO telemetry_simple_user_property_types"
    execute "ALTER TABLE teiserver_telemetry_client_properties RENAME TO telemetry_simple_user_properties"

    execute "ALTER TABLE teiserver_telemetry_unauth_properties RENAME TO telemetry_simple_anon_properties"
    execute "ALTER TABLE teiserver_telemetry_unauth_events RENAME TO telemetry_complex_anon_events"

    execute "ALTER TABLE teiserver_telemetry_match_events RENAME TO telemetry_simple_match_events"
    execute "ALTER TABLE telemetry_match_event_types RENAME TO telemetry_simple_match_event_types"

    execute "ALTER TABLE telemetry_server_event_types RENAME TO telemetry_complex_server_event_types"
    execute "ALTER TABLE teiserver_telemetry_server_events RENAME TO telemetry_complex_server_events"

    execute "ALTER TABLE teiserver_telemetry_infologs RENAME TO telemetry_infologs"

    # Add simple client events
    create table(:telemetry_simple_client_event_types) do
      add :name, :string
    end

    create table(:telemetry_simple_client_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :event_type_id, references(:telemetry_simple_client_event_types, on_delete: :nothing)
      add :timestamp, :utc_datetime
    end

    # Add simple server events
    create table(:telemetry_simple_server_event_types) do
      add :name, :string
    end

    create table(:telemetry_simple_server_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :event_type_id, references(:telemetry_simple_server_event_types, on_delete: :nothing)
      add :timestamp, :utc_datetime
    end

    # Lobby events, simple and complex
    create table(:telemetry_simple_lobby_event_types) do
      add :name, :string
    end

    create table(:telemetry_simple_lobby_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
      add :event_type_id, references(:telemetry_simple_lobby_event_types, on_delete: :nothing)
      add :timestamp, :utc_datetime
    end

    create table(:telemetry_complex_lobby_event_types) do
      add :name, :string
    end

    create table(:telemetry_complex_lobby_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
      add :event_type_id, references(:telemetry_complex_lobby_event_types, on_delete: :nothing)
      add :timestamp, :utc_datetime

      add :value, :jsonb
    end
  end
end
