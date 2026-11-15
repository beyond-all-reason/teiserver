defmodule Teiserver.Repo.Migrations.AddLowerNameEmailIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  @disable_migration_lock true

  # Used by UserLib.valid_name?/2 and UserLib.valid_email?/1, which look users
  # up with `lower(name) = ...` / `lower(email) = ...`. A plain index on the
  # column can't serve those queries, so they were full table scans.
  def change do
    create unique_index(:account_users, ["lower(name)"],
             name: :account_users_lower_name_index,
             concurrently: true
           )

    create unique_index(:account_users, ["lower(email)"],
             name: :account_users_lower_email_index,
             concurrently: true
           )
  end
end
