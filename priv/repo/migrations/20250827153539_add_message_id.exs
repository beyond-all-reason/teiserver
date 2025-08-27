defmodule Teiserver.Repo.Migrations.AddMessageId do
  use Ecto.Migration

  def change do
    alter table(:moderation_reports) do
      add :discord_message_id, :bigint
    end
  end
end
