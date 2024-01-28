defmodule Barserver.Repo.Migrations.AddLobbyPolicies do
  use Ecto.Migration

  def change do
    create table(:lobby_policies) do
      add :name, :string
      add :preset, :string

      add :icon, :string
      add :colour, :string

      add :enabled, :boolean, default: false

      add :map_list, {:array, :string}
      add :agent_name_list, {:array, :string}

      add :agent_name_format, :string
      add :lobby_name_format, :string

      add :min_rating, :integer
      add :max_rating, :integer

      add :min_uncertainty, :integer
      add :max_uncertainty, :integer

      add :min_rank, :integer
      add :max_rank, :integer
      add :min_teamsize, :integer
      add :max_teamsize, :integer

      add :max_teamcount, :integer, default: 2

      timestamps()
    end

    alter table(:teiserver_battle_matches) do
      add :rating_type_id, references(:teiserver_game_rating_types, on_delete: :nothing)
      add :lobby_policy_id, references(:lobby_policies, on_delete: :nothing)
    end
  end
end
