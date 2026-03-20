defmodule Teiserver.Repo.Migrations.CreateObanPeers do
  alias Oban.Migrations

  use Ecto.Migration

  def up, do: Migrations.up(version: 11)

  def down, do: Migrations.down(version: 11)
end
