defmodule Teiserver.Asset.EngineQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_engines() :: [Asset.Engine.t()]
  def get_engines() do
    base_query() |> Repo.all()
  end

  defp base_query() do
    from engine in Asset.Engine, as: :engine
  end
end
