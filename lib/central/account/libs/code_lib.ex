defmodule Central.Account.CodeLib do
  use CentralWeb, :library
  alias Central.Account.Code

  # Queries
  @spec query_codes() :: Ecto.Query.t()
  def query_codes do
    from(codes in Code)
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
    from codes in query,
      where: codes.id == ^id
  end

  def _search(query, :value, value) do
    from codes in query,
      where: codes.value == ^value
  end

  def _search(query, :id_list, id_list) do
    from codes in query,
      where: codes.id in ^id_list
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from codes in query,
      order_by: [desc: codes.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from codes in query,
      order_by: [asc: codes.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_user(query), else: query
    query
  end

  def _preload_user(query) do
    from codes in query,
      left_join: users in assoc(codes, :user),
      preload: [user: users]
  end
end
