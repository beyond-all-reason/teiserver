defmodule Central.Repo.Migrations.MatchIdsInChat do
  use Ecto.Migration

  def change do
    alter table(:teiserver_lobby_messages) do
      add :match_id, references(:teiserver_battle_matches, on_delete: :nothing)
    end

    alter table(:teiserver_battle_matches) do
      add :rating_type_id, references(:teiserver_game_rating_types, on_delete: :nothing)
      add :lobby_policy_id, references(:lobby_policies, on_delete: :nothing)
    end
  end
end
