defmodule Teiserver.Asset do
  alias Teiserver.Asset
  alias Teiserver.Asset.{MapLib, MapQueries}
  alias Teiserver.Asset.EngineQueries
  alias Teiserver.Asset.GameQueries
  alias Teiserver.Repo

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

  @spec get_engines() :: [Asset.Engine.t()]
  defdelegate get_engines(), to: EngineQueries

  def change_engine(%Asset.Engine{} = engine \\ %Asset.Engine{}, attrs \\ %{}) do
    Asset.Engine.changeset(engine, attrs)
  end

  def create_engine(attrs \\ %{}) do
    %Asset.Engine{}
    |> Asset.Engine.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_engine(id :: integer()) :: :ok | :error
  def delete_engine(id) do
    import Ecto.Query

    result =
      from(e in Asset.Engine, where: e.id == ^id)
      |> Repo.delete_all()

    case result do
      {1, _} -> :ok
      {0, _} -> :error
    end
  end

  @spec get_games() :: [Asset.Game.t()]
  defdelegate get_games(), to: GameQueries
end
