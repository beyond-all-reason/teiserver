defmodule Teiserver.Repo.Migrations.RemoveLastLoginMins do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :last_login_mins
    end
  end
end
