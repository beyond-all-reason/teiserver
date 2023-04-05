defmodule Central.Repo.Migrations.WeeklyQuarterlyReports do
  use Ecto.Migration

  def change do
    create table(:teiserver_server_week_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :week, :integer, primary_key: true
      add :week_start, :date

      add :data, :jsonb
    end

    create table(:teiserver_server_quarter_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :quarter, :integer, primary_key: true

      add :data, :jsonb
    end
  end
end
