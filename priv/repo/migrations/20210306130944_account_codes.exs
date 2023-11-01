defmodule Teiserver.Repo.Migrations.AccountCodes do
  use Ecto.Migration

  def change do
    create table(:account_codes) do
      add :value, :string
      # E.g. password reset
      add :purpose, :string
      add :expires, :utc_datetime
      add :metadata, :jsonb

      add :user_id, references(:account_users, on_delete: :nothing)
      timestamps()
    end

    create index(:account_codes, [:value])
  end
  def up do
    execute "CREATE INDEX lower_username ON account_users (LOWER(name))"
  end

  def down do
    execute "DROP INDEX lower_username"
  end
end
