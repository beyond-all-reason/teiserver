defmodule Central.Repo.Migrations.SwappingToAutomodeActions do
  use Ecto.Migration

  def change do
    rename table("teiserver_ban_hashes"), to: table("teiserver_automod_actions")

    alter table(:teiserver_automod_actions) do
      add :enabled, :boolean
      add :reason, :string
      add :actions, :jsonb
      add :expires, :utc_datetime
    end

    execute "UPDATE teiserver_automod_actions SET enabled = true;"
  end
end
