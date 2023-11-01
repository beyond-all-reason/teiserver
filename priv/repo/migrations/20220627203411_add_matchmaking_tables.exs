defmodule Teiserver.Repo.Migrations.AddMatchmakingTables do
  use Ecto.Migration

  def change do
    create table(:teiserver_game_rating_types) do
      add :name, :string
      add :icon, :string
      add :colour, :string
    end

    create table(:teiserver_game_rating_logs) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
      add :rating_type_id, references(:teiserver_game_rating_types, on_delete: :nothing)

      add :party_id, :string
      add :inserted_at, :timestamp
      add :value, :jsonb
    end

    create index(:teiserver_game_rating_logs, [:user_id])
    create index(:teiserver_game_rating_logs, [:match_id])
  end
end
