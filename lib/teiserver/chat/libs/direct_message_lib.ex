defmodule Teiserver.Chat.DirectMessageLib do
  @moduledoc false

  alias Teiserver.Chat.DirectMessage
  alias Teiserver.Chat.TermSearch
  use TeiserverWeb, :library

  # Queries
  @spec query_direct_messages() :: Ecto.Query.t()
  def query_direct_messages do
    from(direct_messages in DirectMessage)
  end

  @spec search(Ecto.Query.t(), map() | nil) :: Ecto.Query.t()
  def search(query, nil), do: query

  def search(query, params) do
    params
    |> Enum.reduce(query, fn {key, value}, query_acc ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t(), atom(), any()) :: Ecto.Query.t()
  def _search(query, _key, ""), do: query
  def _search(query, _key, nil), do: query

  def _search(query, :id, id) do
    from direct_messages in query,
      where: direct_messages.id == ^id
  end

  def _search(query, :member_id_in, []), do: query

  def _search(query, :member_id_in, [id]) do
    from direct_messages in query,
      where: direct_messages.from_id == ^id or direct_messages.to_id == ^id
  end

  def _search(query, :member_id_in, [id1, id2]) do
    from direct_messages in query,
      where:
        (direct_messages.from_id == ^id1 and direct_messages.to_id == ^id2) or
          (direct_messages.from_id == ^id2 and direct_messages.to_id == ^id1)
  end

  def _search(query, :member_id_in, id_list) do
    from direct_messages in query,
      where: direct_messages.from_id in ^id_list and direct_messages.to_id in ^id_list
  end

  def _search(query, :id_list, id_list) do
    from direct_messages in query,
      where: direct_messages.id in ^id_list
  end

  def _search(query, :term, ref) when is_binary(ref) do
    _search(query, :term, {ref, []})
  end

  def _search(query, :term, {ref, opts}) do
    case TermSearch.content_filter(ref, opts) do
      nil -> query
      dynamic -> where(query, ^dynamic)
    end
  end

  def _search(query, :inserted_after, timestamp) do
    from direct_messages in query,
      where: direct_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from direct_messages in query,
      where: direct_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from direct_messages in query,
      order_by: [desc: direct_messages.inserted_at, desc: direct_messages.id]
  end

  def order_by(query, "Oldest first") do
    from direct_messages in query,
      order_by: [asc: direct_messages.inserted_at, asc: direct_messages.id]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    preloads
    |> Enum.reduce(query, fn key, query_acc ->
      _preload(query_acc, key)
    end)
  end

  defp _preload(query, :users) do
    from direct_messages in query,
      left_join: tos in assoc(direct_messages, :to),
      left_join: froms in assoc(direct_messages, :from),
      preload: [to: tos, from: froms]
  end
end
