defmodule Teiserver.Repo.Migrations.UserPreCacheFlag do
  use Ecto.Migration

  def change do
    alter table(:account_users) do
      add :pre_cache, :boolean, default: true
    end
  end
end
