defmodule Teiserver.Account.UserStatLib do
  use CentralWeb, :library
  alias Teiserver.Account.UserStat

  # Queries
  @spec query_user_stats() :: Ecto.Query.t()
  def query_user_stats do
    from(user_stats in UserStat)
  end

  @spec search(Ecto.Query.t(), Map.t() | nil) :: Ecto.Query.t()
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
end
