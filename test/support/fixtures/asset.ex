defmodule Teiserver.AssetFixtures do
  @moduledoc false
  alias Teiserver.Asset
  alias Teiserver.Asset.Engine
  alias Teiserver.Asset.Game
  alias Teiserver.Repo

  def create_map(attrs) do
    %Asset.Map{} |> Asset.Map.changeset(attrs) |> Repo.insert!()
  end

  def create_engine(attrs) do
    %Engine{} |> Engine.changeset(attrs) |> Repo.insert!()
  end

  def drop_engines, do: Repo.delete_all(Engine)

  def create_game(attrs) do
    %Game{} |> Game.changeset(attrs) |> Repo.insert!()
  end

  def drop_games, do: Repo.delete_all(Game)
end
