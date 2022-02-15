defmodule Central.Repo.Migrations.GroupInvites do
  use Ecto.Migration

  def change do
    create table(:account_group_invites, primary_key: false) do
      add :response, :string
      add :user_id, references(:account_users, on_delete: :nothing), primary_key: true
      add :group_id, references(:account_groups, on_delete: :nothing), primary_key: true

      timestamps()
    end

    alter table(:account_groups) do
      add :member_count, :integer
    end
  end
end
