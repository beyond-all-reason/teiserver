defmodule Teiserver.Repo.Migrations.DiscordApplicationCommands do
  use Ecto.Migration

  def change do
    alter table(:communication_text_callbacks) do
      add :category, :text, default: "default", null: false
      remove :triggers
    end

    alter table(:account_users) do
      remove :discord_dm_channel_id
      remove :discord_dm_channel
    end
  end
end
