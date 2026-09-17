defmodule Teiserver.Repo.Migrations.AdditionalIndexes do
  use Ecto.Migration

  def change do
    create index(:telemetry_simple_match_events, [:user_id])
    create index(:telemetry_complex_match_events, [:user_id])
    create index(:telemetry_simple_lobby_events, [:user_id])
    create index(:telemetry_complex_lobby_events, [:user_id])
    create index(:telemetry_simple_server_events, [:user_id])
    create index(:telemetry_complex_server_events, [:user_id])
    create index(:teiserver_battle_matches, [:founder_id])
    create index(:page_view_logs, [:user_id])
    create index(:direct_messages, [:to_id])
    create index(:direct_messages, [:from_id])
    create index(:account_users, [:smurf_of_id])
  end
end
