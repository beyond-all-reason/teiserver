defmodule Central.Repo.Migrations.RemoveChatGuid do
  use Ecto.Migration

  def change do
    alter table(:teiserver_lobby_messages) do
      remove :lobby_guid
    end

    alter table(:moderation_actions) do
      add :hidden, :boolean, default: false
    end
  end
end
