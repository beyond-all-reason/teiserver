defmodule Teiserver.Repo.Migrations.AddDiscordMessageIdToRoomMessages do
  use Ecto.Migration

  def change do
    alter table(:teiserver_room_messages) do
      add :discord_message_id, :bigint
    end
  end
end
