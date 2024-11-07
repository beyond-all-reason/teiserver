defmodule Teiserver.Repo.Migrations.MatchEventTimestamp do
  use Ecto.Migration

  def change do
    alter table(:telemetry_complex_match_events) do
      add :timestamp, :utc_datetime
    end
  end
end
