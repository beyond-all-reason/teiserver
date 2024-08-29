defmodule Teiserver.Account.SmurfKeyLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.SmurfKey

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-regular fa-key"

  @spec colours :: atom
  def colours, do: :info

  # Queries
  @spec query_smurf_keys() :: Ecto.Query.t()
  def query_smurf_keys do
    from(smurf_keys in SmurfKey)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from smurf_keys in query,
      where: smurf_keys.id == ^id
  end

  def _search(query, :id_list, id_list) do
    from smurf_keys in query,
      where: smurf_keys.id in ^id_list
  end

  def _search(query, :value, value) do
    from smurf_keys in query,
      where: smurf_keys.value == ^value
  end

  def _search(query, :value_in, value_list) do
    from smurf_keys in query,
      where: smurf_keys.value in ^value_list
  end

  def _search(query, :value_like, value) do
    value_like = "%" <> String.replace(value, "*", "%") <> "%"

    from smurf_keys in query,
      where: ilike(smurf_keys.value, ^value_like)
  end

  def _search(query, :type_id, type_id) do
    from smurf_keys in query,
      where: smurf_keys.type_id == ^type_id
  end

  def _search(query, :type_id_in, type_ids) do
    from smurf_keys in query,
      where: smurf_keys.type_id in ^type_ids
  end

  def _search(query, :user_id, user_id) do
    from smurf_keys in query,
      where: smurf_keys.user_id == ^user_id
  end

  def _search(query, :user_id_in, user_id_list) do
    from smurf_keys in query,
      where: smurf_keys.user_id in ^user_id_list
  end

  def _search(query, :not_user_id, user_id) do
    from smurf_keys in query,
      where: smurf_keys.user_id != ^user_id
  end

  def _search(query, :not_user_id_in, user_id_list) do
    from smurf_keys in query,
      where: smurf_keys.user_id not in ^user_id_list
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Oldest first") do
    from smurf_keys in query,
      order_by: [asc: smurf_keys.last_updated]
  end

  def order_by(query, "Newest first") do
    from smurf_keys in query,
      order_by: [desc: smurf_keys.last_updated]
  end

  def order_by(query, "ID (High to low)") do
    from smurf_keys in query,
      order_by: [desc: smurf_keys.id]
  end

  def order_by(query, "ID (Low to high)") do
    from smurf_keys in query,
      order_by: [asc: smurf_keys.id]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :type in preloads, do: _preload_type(query), else: query
    query = if :user in preloads, do: _preload_user(query), else: query
    query
  end

  @spec _preload_type(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_type(query) do
    from smurf_keys in query,
      left_join: types in assoc(smurf_keys, :type),
      preload: [type: types]
  end

  @spec _preload_user(Ecto.Query.t()) :: Ecto.Query.t()
  def _preload_user(query) do
    from smurf_keys in query,
      left_join: users in assoc(smurf_keys, :user),
      preload: [user: users]
  end
end
