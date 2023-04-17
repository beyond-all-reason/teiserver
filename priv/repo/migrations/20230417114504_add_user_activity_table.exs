defmodule Central.Repo.Migrations.AddUserActivityLogTable do
  use Ecto.Migration

  def change do
    create table(:telemetry_user_activity_logs, primary_key: false) do
      add :date, :date, primary_key: true
      add :data, :jsonb
    end
  end
end
