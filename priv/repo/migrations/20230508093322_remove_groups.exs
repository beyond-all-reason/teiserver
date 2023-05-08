defmodule Central.Repo.Migrations.RemoveGroups do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :admin_group_id
    end

    alter table(:audit_logs) do
      remove :group_id
    end

    drop table(:account_group_invites)
    drop table(:account_group_memberships)
    drop table(:account_groups)
  end
end
