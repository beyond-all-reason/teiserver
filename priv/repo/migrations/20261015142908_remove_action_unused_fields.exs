defmodule Teiserver.Repo.Migrations.RemoveActionUnusedFields do
  use Ecto.Migration

  def change do
    alter table(:moderation_actions) do
      remove :appeal_status
      remove :score_modifier
    end
  end
end
