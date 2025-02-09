defmodule Teiserver.Repo.Migrations.OriginalScopes do
  use Ecto.Migration

  def up do
    alter table(:oauth_tokens) do
      add_if_not_exists :original_scopes, {:array, :string}, null: true
    end

    execute(fn -> repo().update_all("oauth_tokens", set: [original_scopes: ["tachyon.lobby"]]) end)

    # This is not technically safe if there were multiple connections/applications/nodes
    # because they could insert a record between the backfill operation and
    # the alteration of the column.
    # but this is not a problem for us when this'll be deployed
    # so go for the simple solution
    alter table(:oauth_tokens) do
      modify :original_scopes, {:array, :string}, null: false
    end
  end

  def down do
    alter table(:oauth_tokens) do
      remove_if_exists :original_scopes, {:array, :string}
    end
  end
end
