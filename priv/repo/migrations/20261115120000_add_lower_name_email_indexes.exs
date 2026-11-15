defmodule Teiserver.Repo.Migrations.AddLowerNameEmailIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Used by UserLib.valid_name?/2 and UserLib.valid_email?/1, which look users
  # up with `lower(name) = ...` / `lower(email) = ...`. A plain index on the
  # column can't serve those queries, so they were full table scans.
  def change do
    # Not unique: Steam users are allowed to share a name with other users
    create index(:account_users, ["lower(name)"], concurrently: true)
    create unique_index(:account_users, ["lower(email)"], concurrently: true)
  end
end
