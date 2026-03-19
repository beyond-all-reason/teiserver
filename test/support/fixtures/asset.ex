defmodule Teiserver.AssetFixtures do
  require Logger
  alias Teiserver.Asset
  alias Teiserver.Repo
  alias Asset.Engine
  alias Asset.Game

  def create_map(attrs) do
    %Asset.Map{} |> Asset.Map.changeset(attrs) |> Repo.insert!()
  end

  def create_engine(attrs) do
    %Engine{} |> Engine.changeset(attrs) |> Repo.insert!()
  end

  def create_game(attrs) do
    %Game{} |> Game.changeset(attrs) |> Repo.insert!()
  end
end
