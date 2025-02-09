defmodule Teiserver.AssetFixtures do
  alias Teiserver.Asset
  alias Teiserver.Repo

  def create_map(attrs) do
    %Asset.Map{} |> Asset.Map.changeset(attrs) |> Repo.insert!()
  end
end
