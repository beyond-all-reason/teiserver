defmodule Teiserver.Repo.Migrations.AddObanJobsTable do
  alias Oban.Migrations

  use Ecto.Migration

  def up do
    Migrations.up()
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    Migrations.down(version: 1)
  end
end
