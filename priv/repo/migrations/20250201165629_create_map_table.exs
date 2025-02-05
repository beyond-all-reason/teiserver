defmodule Teiserver.Repo.Migrations.CreateMapTable do
  use Ecto.Migration

  def change do
    create_if_not_exists table("asset_maps", primary_key: false) do
      add :spring_name, :string, primary_key: true, null: false
      add :display_name, :string, null: false
      add :matchmaking_queues, {:array, :string}
      add :thumbnail_url, :string
      add :startboxes_set, :json
      add :modoptions, :json

      timestamps()
    end
  end
end
