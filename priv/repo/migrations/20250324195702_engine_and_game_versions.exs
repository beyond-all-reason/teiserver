defmodule Teiserver.Repo.Migrations.EngineAndGameVersions do
  use Ecto.Migration

  def change do
    create_if_not_exists table("asset_engines") do
      add :name, :text, primary_key: true, null: false
      add :in_matchmaking, :boolean, null: false, default: false
      timestamps(type: :utc_datetime, default: fragment("now()"))
    end

    create unique_index("asset_engines", :name)

    create_if_not_exists table("asset_games") do
      add :name, :text, primary_key: true, null: false
      add :in_matchmaking, :boolean, null: false, default: false
      timestamps(type: :utc_datetime, default: fragment("now()"))
    end

    create unique_index("asset_games", :name)
  end
end
