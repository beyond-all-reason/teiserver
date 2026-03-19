defmodule Teiserver.Repo.Migrations.CreateObanPeers do
  use Ecto.Migration

  alias Oban.Migrations

  def up, do: Migrations.up(version: 11)

  def down, do: Migrations.down(version: 11)
end
