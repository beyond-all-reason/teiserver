defmodule Teiserver.Repo.Migrations.AddDbClusterTables do
  use Ecto.Migration

  def up do
    DBCluster.Migration.up()
  end

  # We specify `version: 1` in `down`, ensuring that we'll roll all the way back down if
  # necessary, regardless of which version we've migrated `up` to.
  def down do
    DBCluster.Migration.down(version: 1)
  end
end
