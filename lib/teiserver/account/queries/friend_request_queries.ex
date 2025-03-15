defmodule Teiserver.Account.FriendRequestQueries do
  @moduledoc false
  use TeiserverWeb, :queries
  alias Teiserver.Account.FriendRequest

  @spec query_friend_requests(list) :: Ecto.Query.t()
  def query_friend_requests(args) do
    query = from(friend_requests in FriendRequest)

    query
    |> do_where(from_user_id: args[:from_user_id])
    |> do_where(to_user_id: args[:to_user_id])
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

  @spec _where(Ecto.Query.t(), Atom.t(), any()) :: Ecto.Query.t()
  defp _where(query, _, ""), do: query
  defp _where(query, _, nil), do: query

  defp _where(query, :from_user_id, from_id) do
    from friend_requests in query,
      where: friend_requests.from_user_id == ^from_id
  end

  defp _where(query, :to_user_id, to_id) do
    from friend_requests in query,
      where: friend_requests.to_user_id == ^to_id
  end

  defp _where(query, :from_to_id, {from_id, to_id}) do
    from friend_requests in query,
      where: friend_requests.from_user_id == ^from_id,
      where: friend_requests.to_user_id == ^to_id
  end

  defp _where(query, :either_user_is, {u1, u2}) do
    from friend_requests in query,
      where:
        (friend_requests.from_user_id == ^u1 and friend_requests.to_user_id == ^u2) or
          (friend_requests.from_user_id == ^u2 and friend_requests.to_user_id == ^u1)
  end

  defp _where(query, :to_or_from_is, id) do
    from friend_requests in query,
      where: friend_requests.from_user_id == ^id or friend_requests.to_user_id == ^id
  end

  @spec do_order_by(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  defp do_order_by(query, nil), do: query

  defp do_order_by(query, params) do
    params
    |> Enum.reduce(query, fn key, query_acc ->
      _order_by(query_acc, key)
    end)
  end

  defp _order_by(query, nil), do: query

  defp _order_by(query, "Newest first") do
    from friend_requests in query,
      order_by: [desc: friend_requests.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from friend_requests in query,
      order_by: [asc: friend_requests.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :to_user) do
    from friend_requests in query,
      join: to_users in assoc(friend_requests, :to_user),
      preload: [to_user: to_users]
  end

  defp _preload(query, :from_user) do
    from friend_requests in query,
      join: from_users in assoc(friend_requests, :from_user),
      preload: [from_user: from_users]
  end
end
