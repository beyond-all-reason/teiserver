defmodule Teiserver.Repo.Migrations.PasswordRework do
  use Ecto.Migration

  def up do
    execute("UPDATE account_users SET password = data->>'password_hash'")
  end

  def down do
    raise Ecto.MigrationError, "Password rework migration not reversible, restore backup instead"
  end
end
