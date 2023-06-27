defmodule Teiserver.Repo.Migrations.WinLossMatchMembership do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :winning_team, :integer, default: nil, null: true
    end

    alter table(:teiserver_battle_match_memberships) do
      add :win, :boolean, default: nil, null: true
      add :stats, :jsonb, default: nil, null: true
    end
  end
end
