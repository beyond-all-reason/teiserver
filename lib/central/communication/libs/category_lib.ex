defmodule Central.Communication.CategoryLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Communication.Category

  @spec colours() :: atom
  def colours(), do: :success

  @spec icon() :: String.t()
  def icon(), do: "far fa-indent"

  # Queries
  @spec get_categories() :: Ecto.Query.t()
  def get_categories do
    from(categories in Category)
  end

  @spec search(Ecto.Query.t(), map | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from categories in query,
      where: categories.id == ^id
  end

  def _search(query, :name, name) do
    from categories in query,
      where: categories.name == ^name
  end

  def _search(query, :public, public) do
    from categories in query,
      where: categories.public == ^public
  end

  def _search(query, :membership, %{assigns: %{memberships: group_ids}}) do
    _search(query, :membership, group_ids)
  end

  def _search(query, :membership, group_ids) do
    from categories in query,
      where: categories.group_id in ^group_ids
  end

  def _search(query, :id_list, id_list) do
    from categories in query,
      where: categories.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from categories in query,
      where: ilike(categories.name, ^ref_like)
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from categories in query,
      order_by: [asc: categories.name]
  end

  def order_by(query, "Name (Z-A)") do
    from categories in query,
      order_by: [desc: categories.name]
  end

  def order_by(query, "Newest first") do
    from categories in query,
      order_by: [desc: categories.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from categories in query,
      order_by: [asc: categories.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end
end
