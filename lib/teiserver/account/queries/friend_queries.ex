defmodule Teiserver.Account.FriendQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Account.Friend

  @spec query_friends(list) :: Ecto.Query.t()
  def query_friends(args) do
    query = from(friends in Friend)

    query
    |> do_where(users: args[:users])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> query_select(args[:select])
  end

  @spec do_where(Ecto.Query.t(), list | map | nil) :: Ecto.Query.t()
  defp do_where(query, nil), do: query

  defp do_where(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _where(query_acc, key, value)
    end)
  end

  @spec _where(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :user1_id, from_id) do
    from friends in query,
      where: friends.user1_id == ^from_id
  end

  defp _where(query, :user2_id, to_id) do
    from friends in query,
      where: friends.user2_id == ^to_id
  end

  defp _where(query, :either_user_is, user_id) do
    from friends in query,
      where: friends.user1_id == ^user_id or friends.user2_id == ^user_id
  end

  defp _where(query, :users, [uid1, uid2]) do
    [user1_id, user2_id] = Enum.sort([uid1, uid2])

    from friends in query,
      where: friends.user1_id == ^user1_id,
      where: friends.user2_id == ^user2_id
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) when is_list(params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp do_order_by(query, param) when is_bitstring(param), do: do_order_by(query, [param])

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from friends in query,
      order_by: [desc: friends.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from friends in query,
      order_by: [asc: friends.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :user1) do
    from friends in query,
      join: froms in assoc(friends, :user1),
      preload: [user1: froms]
  end

  defp _preload(query, :user2) do
    from friends in query,
      join: tos in assoc(friends, :user2),
      preload: [user2: tos]
  end
end
