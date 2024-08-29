defmodule Teiserver.Account.UserStatLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.UserStat

  # Queries
  @spec query_user_stats() :: Ecto.Query.t()
  def query_user_stats do
    from(user_stats in UserStat)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :user_id, id) do
    from user_stats in query,
      where: user_stats.user_id == ^id
  end

  def _search(query, :id_list, id_list) do
    from user_stats in query,
      where: user_stats.user_id in ^id_list
  end

  def _search(query, :data_equal, {"", _}), do: query
  def _search(query, :data_equal, {_, ""}), do: query

  def _search(query, :data_equal, {field, value}) do
    from user_stats in query,
      where: fragment("? ->> ? = ?", user_stats.data, ^field, ^value)
  end

  def _search(query, :data_greater_than, {field, value}) do
    from user_stats in query,
      where: fragment("? ->> ? > ?", user_stats.data, ^field, ^value)
  end

  def _search(query, :data_less_than, {field, value}) do
    from user_stats in query,
      where: fragment("? ->> ? < ?", user_stats.data, ^field, ^value)
  end

  def _search(query, :data_contains, {"", _}), do: query
  def _search(query, :data_contains, {_, ""}), do: query

  def _search(query, :data_contains, {field, value}) do
    from user_stats in query,
      where: fragment("? -> ? @> ?", user_stats.data, ^field, ^value)
  end

  def _search(query, :data_contains_key, field) do
    from user_stats in query,
      where: fragment("? @> ?", user_stats.data, ^field)
  end

  def field_contains(stats, _field, nil), do: stats
  def field_contains(stats, _field, ""), do: stats

  def field_contains(stats, field, value) do
    stats
    |> Stream.filter(fn %{data: data} -> data[field] != nil end)
    |> Stream.filter(fn %{data: data} -> data[field] |> String.contains?(value) end)
  end
end
