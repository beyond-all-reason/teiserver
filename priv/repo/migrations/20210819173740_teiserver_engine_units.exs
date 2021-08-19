defmodule Central.Repo.Migrations.TeiserverEngineUnits do
  use Ecto.Migration

  def change do
    create table(:teiserver_engine_units) do
      add :file_id, :string
      add :name, :string
      add :role, :string
      add :type, :string
      add :description, :string

      add :faction, :string
      add :tier, :integer

      add :metal_cost, :integer
      add :energy_cost, :integer
      add :health, :integer
      add :sight_range, :integer
      add :speed, :integer

      add :attack_range, :integer
      add :rate_of_fire, :integer
      add :damage_per_shot, :integer
      add :dps, :integer

      add :attributes, {:array, :string}
    end

    create index(:teiserver_engine_units, [:file_id])
  end
end
