defmodule Teiserver.Repo.Migrations.RemoveMatchMembershipStats do
  use Ecto.Migration

  def up do
    alter table(:teiserver_battle_match_memberships) do
      remove :stats
    end
  end

  def down do
    raise "Cannot revert removal of membership stats"
  end
end
