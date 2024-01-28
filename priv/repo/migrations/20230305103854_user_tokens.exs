defmodule Barserver.Repo.Migrations.UserTokens do
  use Ecto.Migration

  def change do
    create table(:account_user_tokens) do
      add :user_id, references(:account_users, on_delete: :nothing)
      add :value, :string

      add :user_agent, :string
      add :ip, :string

      add :expires, :utc_datetime
      add :last_used, :utc_datetime

      timestamps()
    end

    create index(:account_user_tokens, [:value])
  end
end
