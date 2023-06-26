defmodule Central.Repo.Migrations.TweakMatchEvents do
  use Ecto.Migration

  def change do
    alter table(:teiserver_telemetry_match_events) do
      remove :timestamp
      remove :value
      add :game_time, :integer
    end

    create table(:significant_timestamps) do
      add :name, :string
      add :description, :text

      add :value, :utc_datetime
    end
  end
end
