defmodule Teiserver.AssetFixtures do
  require Logger
  alias Teiserver.Asset
  alias Teiserver.Repo

  def create_map(attrs) do
    %Asset.Map{} |> Asset.Map.changeset(attrs) |> Repo.insert!()
  end

  def create_or_update_map(attrs) do
    case Asset.get_map(attrs.spring_name) do
      nil -> create_map(attrs)
      map -> update_map(map, attrs)
    end
  end

  def update_map(map, attrs) do
    Logger.warning(
      "Map #{map.spring_name} already exists, adding matchmaking queue #{inspect(attrs.matchmaking_queues)}"
    )

    map
    |> Asset.Map.changeset(%{
      matchmaking_queues: map.matchmaking_queues ++ attrs.matchmaking_queues
    })
    |> Repo.update!()
  end
end
