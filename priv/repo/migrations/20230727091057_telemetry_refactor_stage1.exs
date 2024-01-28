defmodule Barserver.Repo.Migrations.TelemetryRefactorStage1 do
  @doc """
  At the time of writing we have a single event type table which is making
  interface design trickier as it was initially designed to just have client events.

  Stage 1 of the change will create additional tables for other event types and add complex
  match events.
  """
  use Ecto.Migration

  def change do
    # We already have property types

    create table(:telemetry_complex_match_event_types) do
      add :name, :string
    end

    create table(:telemetry_complex_match_events) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :event_type_id, references(:telemetry_complex_match_event_types, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)

      add :game_time, :integer
      add :value, :jsonb
    end
  end
end
