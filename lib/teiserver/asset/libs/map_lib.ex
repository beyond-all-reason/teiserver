defmodule Teiserver.Asset.MapLib do
  alias Teiserver.Asset
  alias Ecto.Multi
  alias Teiserver.Repo

  @spec create_maps([map()]) ::
          {:ok, [Asset.Map.t()]} | {:error, String.t(), Ecto.Changeset.t(), map()}
  def create_maps(map_attrs) do
    names =
      Enum.with_index(map_attrs)
      |> Enum.map(fn {attr, idx} ->
        name = Map.get(attr, "springName", idx)
        "insert-#{name}"
      end)

    tx =
      Enum.reduce(Enum.zip(map_attrs, names), Multi.new(), fn {attr, name}, multi ->
        Multi.insert(multi, name, Asset.Map.changeset(%Asset.Map{}, attr))
      end)
      |> Repo.transaction()

    case tx do
      {:ok, result_map} -> {:ok, Enum.map(names, fn name -> Map.get(result_map, name) end)}
      err -> err
    end
  end
end
