defmodule Teiserver.Repo.Migrations.RemoveLastLoginTimexColumn do
  use Ecto.Migration

  def change do
    # First, migrate data from last_login_timex to last_login for ALL users
    # This ensures all users have consistent last_login data before we remove the old column
    # We overwrite last_login regardless of its current value to prevent format inconsistencies
    execute """
            UPDATE account_users 
            SET last_login = last_login_timex 
            WHERE last_login_timex IS NOT NULL
            """,
            """
            -- No rollback needed for data migration
            """

    # Now remove the redundant column
    alter table(:account_users) do
      remove :last_login_timex
    end
  end
end
