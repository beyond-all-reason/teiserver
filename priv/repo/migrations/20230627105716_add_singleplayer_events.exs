defmodule Central.Repo.Migrations.AddSingleplayerEvents do
  use Ecto.Migration

  def change do
    create table(:telemetry_singleplayer_unauth_events) do
      add :hash, :string
      add :event_type_id, references(:teiserver_telemetry_event_types, on_delete: :nothing)

      add :scenario, :string
      add :timestamp, :utc_datetime
    end

    create table(:telemetry_singleplayer_client_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :event_type_id, references(:teiserver_telemetry_event_types, on_delete: :nothing)

      add :scenario, :string
      add :timestamp, :utc_datetime
    end
  end
end
