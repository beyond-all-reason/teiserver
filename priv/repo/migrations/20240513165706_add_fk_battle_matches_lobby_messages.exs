defmodule Teiserver.Repo.Migrations.AddFkBattleMatchesLobbyMessages do
  use Ecto.Migration
  # This change is being done to reduce the CPU load of the hourly Teiserver.Battle.Tasks.CleanupTask
  # As deleting rows from tables with non-indexed foreign keys is probably expensive
  # This migration adds indexes on the columns used as foreign key on the battle_matches table

  def change do
    create index(:teiserver_battle_match_memberships, [:match_id])
    create index(:teiserver_lobby_messages, [:match_id])
    create index(:moderation_reports, [:match_id])
    create index(:telemetry_simple_match_events, [:match_id])
    create index(:telemetry_complex_match_events, [:match_id])
    create index(:telemetry_simple_lobby_events, [:match_id])
    create index(:telemetry_complex_lobby_events, [:match_id])
    create index(:moderation_report_groups, [:match_id])
  end
end
