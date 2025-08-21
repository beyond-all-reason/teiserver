defmodule Teiserver.Repo.Migrations.RemoveLastLoginTimexColumn do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :last_login_timex
    end
  end
end
