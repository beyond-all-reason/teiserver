defmodule Central.Repo.Migrations.AddUsernameIndexes do
  use Ecto.Migration

  def change do
    create index(:account_users, [:name])
  end

  def up do
    execute "CREATE INDEX lower_username ON account_users (LOWER(name))"
  end

  def down do
    execute "DROP INDEX lower_username"
  end
end
