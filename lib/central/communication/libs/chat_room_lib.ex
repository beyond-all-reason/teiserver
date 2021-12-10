defmodule Central.Communication.ChatRoomLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Communication.ChatRoom

  def colours(), do: Central.Helpers.StylingHelper.colours(:success)
  def icon(), do: "far fa-comment"

  def icon_full(), do: "fas fa-comment"
  def icon_empty(), do: "far fa-comment"

  # Queries
  @spec get_chat_rooms() :: Ecto.Query.t()
  def get_chat_rooms do
    from(chat_rooms in ChatRoom)
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
    from chat_rooms in query,
      where: chat_rooms.id == ^id
  end

  def _search(query, :name, name) do
    from chat_rooms in query,
      where: chat_rooms.name == ^name
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :content in preloads, do: _preload_content(query), else: query
    query = if :full_content in preloads, do: _preload_full_content(query), else: query

    query
  end

  def _preload_full_content(query) do
    from chat_rooms in query,
      left_join: contents in assoc(chat_rooms, :content),
      left_join: users in assoc(contents, :user),
      order_by: [desc: contents.inserted_at, desc: contents.id],
      preload: [content: {contents, user: users}]
  end

  def _preload_content(query) do
    from chat_rooms in _preload_full_content(query),
      limit: 30
  end
end
