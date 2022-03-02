defmodule Central.Repo.Migrations.AddingQueueFlagToMatches do
  use Ecto.Migration

  def change do
    alter table(:teiserver_battle_matches) do
      add :queue_id, references(:teiserver_game_queues, on_delete: :nothing)
    end
  end
end
