defmodule Teiserver.Asset.MapQueries do
  use TeiserverWeb, :queries

  alias Teiserver.Asset

  @spec get_map(String.t()) :: Asset.Map.t() | nil
  def get_map(spring_name) do
    base_query() |> where_spring_name(spring_name) |> Repo.one()
  end

  @spec get_all_maps() :: [Asset.Map.t()]
  def get_all_maps() do
    base_query() |> Repo.all()
  end

  @spec delete_all_maps() :: non_neg_integer()
  def delete_all_maps() do
    {n, _} = base_query() |> Repo.delete_all()
    n
  end

  defp base_query() do
    from map in Asset.Map, as: :map
  end

  defp where_spring_name(query, name) do
    from [map: map] in query,
      where: map.spring_name == ^name
  end
end
