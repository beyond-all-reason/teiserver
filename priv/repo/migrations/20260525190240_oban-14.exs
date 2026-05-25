defmodule :"Elixir.Teiserver.Repo.Migrations.Oban-14" do
  alias Oban.Migrations

  use Ecto.Migration

  def up, do: Migrations.up(version: 14)
  def down, do: Migrations.down(version: 14)
end
