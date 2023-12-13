defmodule Teiserver.Repo.Migrations.AccountIndexes do
  use Ecto.Migration

  def up do
    execute "CREATE INDEX lower_username ON account_users (LOWER(name))"
  end

  def down do
    execute "DROP INDEX lower_username"
  end
end
