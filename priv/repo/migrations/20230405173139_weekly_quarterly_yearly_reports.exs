defmodule Teiserver.Repo.Migrations.WeeklyQuarterlyReports do
  use Ecto.Migration

  def change do
    create table(:teiserver_server_week_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :week, :integer, primary_key: true
      add :date, :date

      add :data, :jsonb
    end

    create table(:teiserver_server_quarter_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :quarter, :integer, primary_key: true
      add :date, :date

      add :data, :jsonb
    end

    create table(:teiserver_server_year_logs, primary_key: false) do
      add :year, :integer, primary_key: true
      add :date, :date

      add :data, :jsonb
    end

    alter table(:teiserver_server_month_logs) do
      add :date, :date
    end
  end
end
