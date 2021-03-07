defmodule Central.Repo.Migrations.UserGroups do
  use Ecto.Migration

  def change do
    create table(:account_groups) do
      add :name, :string
      add :icon, :string
      add :colour, :string
      add :data, :jsonb

      add :active, :boolean
      add :group_type, :string

      add :see_group, :boolean
      add :see_members, :boolean
      add :invite_members, :boolean
      add :self_add_members, :boolean

      add :super_group_id, references(:account_groups, on_delete: :nothing)

      add :children_cache, {:array, :integer}
      add :supers_cache, {:array, :integer}

      timestamps()
    end

    create index(:account_groups, [:super_group_id])

    create table(:account_group_memberships, primary_key: false) do
      add :admin, :boolean, default: false, null: false
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :group_id, references(:account_groups, on_delete: :nothing), primary_key: true

      timestamps()
    end

    create index(:account_group_memberships, [:user_id])
    create index(:account_group_memberships, [:group_id])

    alter table(:account_users) do
      add :admin_group_id, references(:account_groups, on_delete: :nothing)
    end
  end
end
