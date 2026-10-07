defmodule Teiserver.Repo.Migrations.AddDurationToModerationActions do
  use Ecto.Migration

  def change do
    alter table(:moderation_actions) do
      add :duration, :bigint, null: true
      modify :expires, :naive_datetime, null: true, from: {:naive_datetime, null: false}
    end
  end
end
