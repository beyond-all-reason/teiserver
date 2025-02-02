defmodule Teiserver.Asset do
  alias Teiserver.Asset
  alias Teiserver.Asset.{MapLib, MapQueries}

  @spec create_maps([map()]) :: {:ok, [Asset.Map.t()]} | {:error, Ecto.Changeset.t()}
  defdelegate create_maps(map_attrs), to: MapLib

  @spec get_map(String.t()) :: Asset.Map.t() | nil
  defdelegate get_map(spring_name), to: MapQueries

  @spec get_all_maps() :: [Asset.Map.t()]
  defdelegate get_all_maps(), to: MapQueries

  @spec delete_all_maps() :: non_neg_integer()
  defdelegate delete_all_maps(), to: MapQueries
end
