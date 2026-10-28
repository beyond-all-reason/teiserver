defmodule Teiserver.Repo.Migrations.ExpandUserFields do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :rank, :integer, default: 0
      add :country, :text, default: "??"
      add :bot, :boolean, default: false
      add :email_change_code, :text
      add :last_login_mins, :integer
      add :lobby_hash, :text
      add :chobby_hash, :text
      add :lobby_client, :text
      add :discord_dm_channel, :bigint
    end
  end
end
