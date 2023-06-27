defmodule Teiserver.Repo.Migrations.Queues do
  use Ecto.Migration

  def change do
    create table(:teiserver_game_queues) do
      add :name, :string
      add :team_size, :integer

      add :icon, :string
      add :colour, :string

      add :conditions, :jsonb
      add :settings, :jsonb
      add :map_list, {:array, :string}

      timestamps()
    end
  end
end
