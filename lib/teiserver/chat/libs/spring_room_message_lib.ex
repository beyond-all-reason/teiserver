defmodule Teiserver.Chat.SpringRoomMessageLib do
  @moduledoc false
  alias Teiserver.Chat.SpringRoomMessage
  alias Teiserver.Chat.TermSearch
  use TeiserverWeb, :library

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-comment"

  @spec colours :: atom
  def colours, do: :default

  # Queries
  @spec query_spring_room_messages() :: Ecto.Query.t()
  def query_spring_room_messages do
    from(spring_room_messages in SpringRoomMessage)
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
    from spring_room_messages in query,
      where: spring_room_messages.id == ^id
  end

  def _search(query, :id_less_than, id) do
    from spring_room_messages in query,
      where: spring_room_messages.id < ^id
  end

  def _search(query, :user_id, user_id) do
    from spring_room_messages in query,
      where: spring_room_messages.user_id == ^user_id
  end

  def _search(query, :user_id_in, id_list) do
    from spring_room_messages in query,
      where: spring_room_messages.user_id in ^id_list
  end

  def _search(query, :chat_room, chat_room) do
    from spring_room_messages in query,
      where: spring_room_messages.chat_room == ^chat_room
  end

  def _search(query, :user_id_not_in, id_list) do
    from spring_room_messages in query,
      where: spring_room_messages.user_id not in ^id_list
  end

  def _search(query, :id_list, id_list) do
    from spring_room_messages in query,
      where: spring_room_messages.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from spring_room_messages in query,
      where: ilike(spring_room_messages.name, ^ref_like)
  end

  def _search(query, :term, ref) when is_binary(ref) do
    _search(query, :term, {ref, []})
  end

  def _search(query, :term, {ref, opts}) do
    TermSearch.content_filter(query, ref, opts)
  end

  def _search(query, :inserted_after, timestamp) do
    from spring_room_messages in query,
      where: spring_room_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from spring_room_messages in query,
      where: spring_room_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from spring_room_messages in query,
      order_by: [asc: spring_room_messages.name]
  end

  def order_by(query, "Name (Z-A)") do
    from spring_room_messages in query,
      order_by: [desc: spring_room_messages.name]
  end

  def order_by(query, "Newest first") do
    from spring_room_messages in query,
      order_by: [desc: spring_room_messages.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from spring_room_messages in query,
      order_by: [asc: spring_room_messages.inserted_at]
  end

  @spec preload(Ecto.Query.t(), list() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_users(query) do
    from spring_room_messages in query,
      left_join: users in assoc(spring_room_messages, :user),
      preload: [user: users]
  end
end
