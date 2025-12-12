defmodule Teiserver.Chat.DirectMessageLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Helper.QueryHelpers
  alias Teiserver.Chat.DirectMessage

  # Queries
  @spec query_direct_messages(list) :: Ecto.Query.t()
  def query_direct_messages(args) do
    query = from(direct_messages in DirectMessage)

    query
    |> do_where(id: args[:id])
    |> do_where(args[:where])
    |> do_preload(args[:preload])
    |> do_order_by(args[:order_by])
    |> QueryHelpers.query_select(args[:select])
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

  defp _where(query, :id, id) do
    from direct_messages in query,
      where: direct_messages.id == ^id
  end

  defp _where(query, :members, {u1, u2}) when is_integer(u1) and is_integer(u2) do
    from direct_messages in query,
      where: direct_messages.to_id in [^u1, ^u2] or direct_messages.from_id in [^u1, ^u2]
  end

  defp _where(query, :id_in, id_list) do
    from direct_messages in query,
      where: direct_messages.id in ^id_list
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
    from direct_messages in query,
      order_by: [desc: direct_messages.updated_at]
  end

  defp _order_by(query, "Oldest first") do
    from direct_messages in query,
      order_by: [asc: direct_messages.updated_at]
  end

  @spec do_preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  defp do_preload(query, nil), do: query

  defp do_preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :users) do
    from direct_messages in query,
      join: tos in assoc(direct_messages, :to),
      preload: [to: tos],
      join: froms in assoc(direct_messages, :from),
      preload: [from: froms]
  end
end
