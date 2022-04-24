defmodule Central.Repo.Migrations.RemovalOfUserPreCacheField do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      remove :pre_cache, :boolean, default: true
    end
  end
end
