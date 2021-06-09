defmodule Central.Repo.Migrations.BattleLogs do
  use Ecto.Migration

  def change do
    create table(:teiserver_battle_logs) do
      add :map, :string
      add :data, :jsonb

      add :team_count, :integer
      add :players, {:array, :integer}
      add :spectators, {:array, :integer}

      add :started, :utc_datetime
      add :finished, :utc_datetime

      timestamps()
    end
  end
end
