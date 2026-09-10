defmodule Teiserver.Repo.Migrations.RemoveDiscordDmChannel do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :discord_dm_channel_id
      remove :discord_dm_channel
    end
  end
end
