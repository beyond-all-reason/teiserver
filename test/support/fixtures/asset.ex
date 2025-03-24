defmodule Teiserver.AssetFixtures do
  require Logger
  alias Teiserver.Asset
  alias Teiserver.Repo

  def create_map(attrs) do
    %Asset.Map{} |> Asset.Map.changeset(attrs) |> Repo.insert!()
  end

  def create_engine(attrs) do
    %Asset.Engine{} |> Asset.Engine.changeset(attrs) |> Repo.insert!()
  end

  def create_game(attrs) do
    %Asset.Game{} |> Asset.Game.changeset(attrs) |> Repo.insert!()
  end
end
