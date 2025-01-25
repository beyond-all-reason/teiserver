defmodule Teiserver.Repo.Migrations.AutohostRename do
  use Ecto.Migration

  def change do
    rename table("teiserver_autohosts"), to: table("teiserver_bots")
    rename table("oauth_tokens"), :autohost_id, to: :bot_id
    rename table("oauth_credentials"), :autohost_id, to: :bot_id

    execute(
      ~s(ALTER TABLE oauth_tokens RENAME CONSTRAINT "oauth_tokens_autohost_id_fkey" TO "oauth_tokens_bot_id_fkey"),
      ~s(ALTER TABLE oauth_tokens RENAME CONSTRAINT "oauth_tokens_bot_id_fkey" TO "oauth_tokens_autohost_id_fkey")
    )

    execute(
      ~s(ALTER TABLE oauth_credentials RENAME CONSTRAINT "oauth_credentials_autohost_id_fkey" TO "oauth_credentials_bot_id_fkey"),
      ~s(ALTER TABLE oauth_credentials RENAME CONSTRAINT "oauth_credentials_bot_id_fkey" TO "oauth_tokencredentialshost_id_fkey")
    )

    alter table("teiserver_bots") do
      add :type, :text
    end
  end
end
