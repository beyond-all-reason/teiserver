defmodule Teiserver.Repo.Migrations.SteamAccountCreation do
  use Ecto.Migration

  def change do
    create unique_index(:account_users, [:steam_id])

    # Name was always required, this just makes it enforced in DB as well
    alter table(:account_users) do
      modify :name, :text, null: false
    end
  end
end
