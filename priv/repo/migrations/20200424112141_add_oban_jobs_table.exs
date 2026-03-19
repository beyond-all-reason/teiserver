defmodule Teiserver.Repo.Migrations.AddObanJobsTable do
  use Ecto.Migration

  alias Oban.Migrations

  def up do
    Migrations.up()
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    Migrations.down(version: 1)
  end
end
