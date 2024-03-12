defmodule Barserver.Repo.Migrations.BarserverBattleMatches do
  use Ecto.Migration

  def change do
    create table(:teiserver_battle_matches) do
      add :uuid, :string
      add :map, :string
      add :data, :jsonb
      add :tags, :jsonb

      add :team_count, :integer
      add :team_size, :integer
      add :passworded, :boolean
      add :game_type, :string

      add :processed, :boolean

      add :founder_id, references(:account_users, on_delete: :nothing)
      add :bots, :jsonb

      add :started, :utc_datetime
      add :finished, :utc_datetime

      add :game_duration, :integer
      add :winning_team, :integer, default: nil, null: true

      add :server_uuid, :string

      add :queue_id, references(:teiserver_game_queues, on_delete: :nothing)

      timestamps()
    end

    create index(:teiserver_battle_matches, [:uuid])

    create table(:teiserver_battle_match_memberships, primary_key: false) do
      add :team_id, :integer
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing), primary_key: true
      add :left_after, :integer
      add :party_id, :string

      add :win, :boolean, default: nil, null: true
      add :stats, :jsonb, default: nil, null: true
    end
  end
end
