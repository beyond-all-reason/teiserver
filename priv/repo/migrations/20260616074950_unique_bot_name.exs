defmodule Teiserver.Repo.Migrations.UniqueBotName do
  use Ecto.Migration

  def change do
    create unique_index(:teiserver_bots, [:name])
  end
end
