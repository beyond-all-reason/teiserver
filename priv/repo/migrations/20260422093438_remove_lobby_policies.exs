defmodule Teiserver.Repo.Migrations.RemoveLobbyPolicies do
  use Ecto.Migration

  def up do
    alter table(:teiserver_battle_matches) do
      remove :lobby_policy_id
    end

    drop table(:lobby_policies)
  end

  def down do
    raise "Cannot revert removal of lobby policies"
  end
end
