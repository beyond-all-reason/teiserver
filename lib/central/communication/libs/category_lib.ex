defmodule Central.Communication.CategoryLib do
  use CentralWeb, :library

  alias Central.Communication.Category

  def colours(), do: {"#2A4", "#EFE", "success"}
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

  def _search(query, :simple_search, ref) do
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

  # def _preload_things(query) do
  #   from categories in query,
  #     left_join: things in assoc(categories, :things),
  #     preload: [things: things]
  # end

  # @spec get_category(integer) :: Ecto.Query.t
  # def get_category(category_id) do
  #   from categories in Category,
  #     where: categories.id == ^category_id
  # end

  # @spec get_categories() :: Ecto.Query.t
  # def get_categories() do
  #   from categories in Category
  # end

  # @spec search(Ecto.Query.t, atom, nil) :: Ecto.Query.t
  # @spec search(Ecto.Query.t, atom, String.t()) :: Ecto.Query.t
  # def search(query, _, nil), do: query
  # def search(query, _, ""), do: query

  # def search(query, :simple_search, value) do
  #   value_like = "%" <> String.replace(value, "*", "%") <> "%"

  #   # TODO from blueprints
  #   # Put in the simple-search strings here

  #   from categories in query,
  #     where: (
  #            ilike(categories.str1, ^value_like)
  #         or ilike(categories.str2, ^value_like)
  #       )
  # end

  # def search(query, :name, name) do
  #   name = "%" <> String.replace(name, "*", "%") <> "%"

  #   from categories in query,
  #     where: ilike(categories.name, ^name)
  # end

  # def search(query, :colour, colour) do
  #   colour = "%" <> String.replace(colour, "*", "%") <> "%"

  #   from categories in query,
  #     where: ilike(categories.colour, ^colour)
  # end

  # def search(query, :icon, icon) do
  #   icon = "%" <> String.replace(icon, "*", "%") <> "%"

  #   from categories in query,
  #     where: ilike(categories.icon, ^icon)
  # end

  # def search(query, :inserted_at_start, inserted_at_start) do
  #   inserted_at_start = Timex.parse!(inserted_at_start, "{0D}/{0M}/{YYYY}")

  #   from p in query,
  #     where: p.inserted_at > ^inserted_at_start
  # end

  # def search(query, :inserted_at_end, inserted_at_end) do
  #   inserted_at_end = Timex.parse!(inserted_at_end, "{0D}/{0M}/{YYYY}")

  #   from p in query,
  #     where: p.inserted_at < ^inserted_at_end
  # end
end
