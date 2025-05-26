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

  @type startbox :: MapLib.startbox()
  @spec get_startboxes(Asset.Map.t(), number_of_teams :: non_neg_integer()) :: [startbox()] | nil
  defdelegate get_startboxes(map, number_of_teams), to: MapLib

  @spec get_engines() :: [Asset.Engine.t()]
  defdelegate get_engines(), to: EngineQueries

  @spec get_engine(EngineQueries.where_opts()) :: Asset.Engine.t() | nil
  defdelegate get_engine(attr), to: EngineQueries

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

  @spec set_engine_matchmaking(id :: integer() | String.t()) ::
          {:ok, Asset.Engine.t()} | {:error, :not_found}
  def set_engine_matchmaking(id) do
    res =
      Repo.transaction(fn ->
        case EngineQueries.get_engine(id: id) do
          nil ->
            Repo.rollback(:not_found)

          engine ->
            mm_engine = EngineQueries.get_engine(in_matchmaking: true)

            if mm_engine != nil do
              change_engine(mm_engine, %{in_matchmaking: false}) |> Repo.update!()
            end

            change_engine(engine, %{in_matchmaking: true}) |> Repo.update!()
        end
      end)

    case res do
      {:ok, _} -> Teiserver.Matchmaking.restart_queues()
      _ -> nil
    end

    res
  end

  @spec get_games() :: [Asset.Game.t()]
  defdelegate get_games(), to: GameQueries

  @spec get_game(GameQueries.where_opts()) :: Asset.Game.t() | nil
  defdelegate get_game(attr), to: GameQueries

  def change_game(%Asset.Game{} = game \\ %Asset.Game{}, attrs \\ %{}) do
    Asset.Game.changeset(game, attrs)
  end

  def create_game(attrs \\ %{}) do
    %Asset.Game{}
    |> Asset.Game.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_game(id :: integer()) :: :ok | :error
  def delete_game(id) do
    import Ecto.Query

    result =
      from(e in Asset.Game, where: e.id == ^id)
      |> Repo.delete_all()

    case result do
      {1, _} -> :ok
      {0, _} -> :error
    end
  end

  @spec set_game_matchmaking(id :: integer() | String.t()) ::
          {:ok, Asset.Game.t()} | {:error, :not_found}
  def set_game_matchmaking(id) do
    res =
      Repo.transaction(fn ->
        case GameQueries.get_game(id: id) do
          nil ->
            Repo.rollback(:not_found)

          game ->
            mm_game = GameQueries.get_game(in_matchmaking: true)

            if mm_game != nil do
              change_game(mm_game, %{in_matchmaking: false}) |> Repo.update!()
            end

            change_game(game, %{in_matchmaking: true}) |> Repo.update!()
        end
      end)

    case res do
      {:ok, _} -> Teiserver.Matchmaking.restart_queues()
      _ -> nil
    end

    res
  end
end
