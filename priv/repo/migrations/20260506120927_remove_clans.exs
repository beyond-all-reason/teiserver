defmodule Teiserver.Repo.Migrations.RemoveClans do
  use Ecto.Migration

  def up do
    alter table(:account_users) do
      remove :clan_id
    end

    drop table(:teiserver_clan_invites)
    drop table(:teiserver_clan_memberships)
    drop table(:teiserver_clans)
  end

  def down do
    raise "Cannot revert removal of clans"
  end
end
