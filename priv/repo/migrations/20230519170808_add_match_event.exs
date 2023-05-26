defmodule Central.Repo.Migrations.AddMatchEvent do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_match_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
      add :timestamp, :utc_datetime

      add :event_type_id, references(:teiserver_telemetry_event_types, on_delete: :nothing)
      add :value, :jsonb
    end
  end
end
