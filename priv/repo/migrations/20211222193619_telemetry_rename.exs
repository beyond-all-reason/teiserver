defmodule Central.Repo.Migrations.TelemetryRename do
  use Ecto.Migration

  def change do
    rename table("teiserver_telemetry_minute_logs"), to: table("teiserver_server_minute_logs")
    rename table("teiserver_telemetry_day_logs"), to: table("teiserver_server_day_logs")
    rename table("teiserver_telemetry_month_logs"), to: table("teiserver_server_month_logs")
  end
end
