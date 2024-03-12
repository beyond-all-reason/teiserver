defmodule Barserver.Repo.Migrations.MonthlyTelemetry do
  use Ecto.Migration

  def change do
    create table(:teiserver_telemetry_month_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :month, :integer, primary_key: true

      add :data, :jsonb
    end
  end
end
