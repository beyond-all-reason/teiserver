defmodule Teiserver.Repo.Migrations.AddLowerNameEmailIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Used by UserLib.valid_name?/2 and UserLib.valid_email?/1, which look users
  # up with `lower(name) = ...` / `lower(email) = ...`. A plain index on the
  # column can't serve those queries, so they were full table scans.
  # These indexes replace the case-sensitive ones.
  def up do
    drop index(:account_users, [:name], name: :account_users_name_index, concurrently: true)
    drop index(:account_users, [:email], name: :account_users_email_index, concurrently: true)
    execute "DROP INDEX CONCURRENTLY lower_username"

    # Not unique: Steam users are allowed to share a name with other users
    create index(:account_users, ["lower(name)"],
             name: :account_users_name_index,
             concurrently: true
           )

    # Keeps the default name, which `unique_constraint(:email)` relies on
    create unique_index(:account_users, ["lower(email)"],
             name: :account_users_email_index,
             concurrently: true
           )
  end

  def down do
    drop index(:account_users, ["lower(name)"],
           name: :account_users_name_index,
           concurrently: true
         )

    drop index(:account_users, ["lower(email)"],
           name: :account_users_email_index,
           concurrently: true
         )

    create index(:account_users, [:name], concurrently: true)
    create unique_index(:account_users, [:email], concurrently: true)
    execute "CREATE INDEX CONCURRENTLY lower_username ON account_users (LOWER(name))"
  end
end
