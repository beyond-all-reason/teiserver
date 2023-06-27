defmodule Teiserver.Repo.Migrations.MatchTelemetry do
  use Ecto.Migration

  def change do
    create table(:teiserver_match_day_logs, primary_key: false) do
      add :date, :date, primary_key: true

      add :data, :jsonb
    end

    create table(:teiserver_match_month_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :month, :integer, primary_key: true

      add :data, :jsonb
    end
  end
end
