defmodule Teiserver.Asset.EngineQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_engines() :: [Asset.Engine.t()]
  def get_engines() do
    base_query() |> order_by() |> Repo.all()
  end

  @spec get_engine([id: integer() | String.t()] | [name: String.t()]) :: Asset.Engine.t() | nil
  def get_engine(id: id), do: base_query() |> where_id(id) |> Repo.one()
  def get_engine(name: name), do: base_query() |> where_name(name) |> Repo.one()

  defp base_query() do
    from engine in Asset.Engine, as: :engine
  end

  defp order_by(query) do
    from engine in query, order_by: [desc: engine.id]
  end

  def where_id(query, id) do
    from engine in query, where: engine.id == ^id
  end

  def where_name(query, name) do
    from engine in query, where: engine.name == ^name
  end
end
