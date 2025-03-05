defmodule Teiserver.Asset do
  alias Teiserver.Asset
  alias Teiserver.Asset.{MapLib, MapQueries}

  @spec create_maps([map()]) ::
          {:ok, [Asset.Map.t()]} | {:error, String.t(), Ecto.Changeset.t(), map()}
  defdelegate create_maps(map_attrs), to: MapLib

  @spec get_map(String.t()) :: Asset.Map.t() | nil
  defdelegate get_map(spring_name), to: MapQueries

  @spec get_maps_for_queue(Teiserver.Matchmaking.queue_id()) :: [Asset.Map.t()] | nil
  defdelegate get_maps_for_queue(spring_name), to: MapQueries

  @spec get_all_maps() :: [Asset.Map.t()]
  defdelegate get_all_maps(), to: MapQueries

  @spec delete_all_maps() :: non_neg_integer()
  defdelegate delete_all_maps(), to: MapQueries

  @spec update_maps([map()]) ::
          {:ok, %{deleted_count: non_neg_integer(), created_count: non_neg_integer()}}
          | {:error, :bad_request}
          | {:error, {String.t(), Ecto.Changeset.t()}}
  def update_maps(map_attrs) do
    Teiserver.Repo.transaction(fn ->
      n = delete_all_maps()

      case create_maps(map_attrs) do
        {:ok, maps} ->
          %{
            deleted_count: n,
            created_count: Enum.count(maps)
          }

        {:error, opname, changeset, _changes_so_far} ->
          Teiserver.Repo.rollback({opname, changeset})
      end
    end)
  end
end
