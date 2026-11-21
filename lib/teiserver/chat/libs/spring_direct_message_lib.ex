defmodule Teiserver.Chat.SpringDirectMessageLib do
  @moduledoc false

  alias Teiserver.Chat.SpringDirectMessage
  alias Teiserver.Chat.TermSearch
  use TeiserverWeb, :library

  # Queries
  @spec query_spring_direct_messages() :: Ecto.Query.t()
  def query_spring_direct_messages do
    from(spring_direct_messages in SpringDirectMessage)
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
    from spring_direct_messages in query,
      where: spring_direct_messages.id == ^id
  end

  def _search(query, :member_id_in, []), do: query

  def _search(query, :member_id_in, [id]) do
    from spring_direct_messages in query,
      where: spring_direct_messages.from_id == ^id or spring_direct_messages.to_id == ^id
  end

  def _search(query, :member_id_in, [id1, id2]) do
    from spring_direct_messages in query,
      where:
        (spring_direct_messages.from_id == ^id1 and spring_direct_messages.to_id == ^id2) or
          (spring_direct_messages.from_id == ^id2 and spring_direct_messages.to_id == ^id1)
  end

  def _search(query, :member_id_in, id_list) do
    from spring_direct_messages in query,
      where:
        spring_direct_messages.from_id in ^id_list and spring_direct_messages.to_id in ^id_list
  end

  def _search(query, :id_list, id_list) do
    from spring_direct_messages in query,
      where: spring_direct_messages.id in ^id_list
  end

  def _search(query, :term, ref) when is_binary(ref) do
    _search(query, :term, {ref, []})
  end

  def _search(query, :term, {ref, opts}) do
    TermSearch.content_filter(query, ref, opts)
  end

  def _search(query, :inserted_after, timestamp) do
    from spring_direct_messages in query,
      where: spring_direct_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from spring_direct_messages in query,
      where: spring_direct_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Newest first") do
    from spring_direct_messages in query,
      order_by: [desc: spring_direct_messages.inserted_at, desc: spring_direct_messages.id]
  end

  def order_by(query, "Oldest first") do
    from spring_direct_messages in query,
      order_by: [asc: spring_direct_messages.inserted_at, asc: spring_direct_messages.id]
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
    from spring_direct_messages in query,
      left_join: tos in assoc(spring_direct_messages, :to),
      left_join: froms in assoc(spring_direct_messages, :from),
      preload: [to: tos, from: froms]
  end
end
