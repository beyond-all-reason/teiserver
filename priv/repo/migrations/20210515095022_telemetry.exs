defmodule Central.Repo.Migrations.Telemetry do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_log, primary_key: false) do
      add :timestamp, :utc_datetime, primary_key: true

      add :data, :jsonb
    end
  end
end
