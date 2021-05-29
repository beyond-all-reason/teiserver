defmodule Central.Repo.Migrations.Telemetry do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_minute_logs, primary_key: false) do
      add :timestamp, :utc_datetime, primary_key: true

      add :data, :jsonb
    end

    create table(:teiserver_telemetry_day_logs, primary_key: false) do
      add :date, :date, primary_key: true

      add :data, :jsonb
    end
  end
end
