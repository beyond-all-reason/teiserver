defmodule Central.Repo.Migrations.UuidOssp do
  use Ecto.Migration

  def up do
    execute "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\";"
  end

  def down do
    execute "DROP EXTENSION uuid-ossp"
  end
end
