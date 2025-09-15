defmodule Teiserver.Asset.EngineQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_engines() :: [Asset.Engine.t()]
  def get_engines() do
    base_query() |> order_by() |> Repo.all()
  end

  @type where_opt ::
          {:id, integer() | String.t()} | {:name, String.t()} | {:in_matchmaking, boolean()}
  @type where_opts :: [where_opt()]

  @spec get_engine(where_opts()) :: Asset.Engine.t() | nil
  def get_engine(clauses) do
    Enum.reduce(clauses, base_query(), fn clause, q ->
      case clause do
        {:id, id} -> where_id(q, id)
        {:name, name} -> where_name(q, name)
        {:in_matchmaking, mm} -> where_in_matchmaking(q, mm)
      end
    end)
    |> Repo.one()
  end

  @doc """
  When creating a lobby, use this engine version.
  """
  @spec get_default_lobby_engine() :: Asset.Engine.t() | nil
  def get_default_lobby_engine() do
    # for now, just return the same game as for matchmaking
    get_engine(in_matchmaking: true)
  end

  defp base_query() do
    from engine in Asset.Engine, as: :engine
  end

  defp order_by(query) do
    from engine in query, order_by: [desc: engine.id]
  end

  def where_id(query, nil), do: from(engine in query, where: is_nil(engine.id))
  def where_id(query, id), do: from(engine in query, where: engine.id == ^id)

  def where_name(query, name) do
    from engine in query, where: engine.name == ^name
  end

  def where_in_matchmaking(query, mm) do
    from engine in query, where: engine.in_matchmaking == ^mm
  end
end
