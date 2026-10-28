defmodule Teiserver.Repo.Migrations.RemoveDiscordChannelUnusedFields do
  use Ecto.Migration

  def change do
    alter table(:communication_discord_channels) do
      remove :icon
      remove :colour
      remove :view_permission
      remove :post_permission
    end
  end
end
