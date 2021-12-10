defmodule Central.Communication.ChatContentLib do
  @moduledoc false
  use CentralWeb, :library

  alias Central.Communication.ChatContent

  # Queries
  @spec get_chat_contents() :: Ecto.Query.t()
  def get_chat_contents do
    from(chat_contents in ChatContent)
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

  def _search(query, :chat_room_id, chat_room_id) do
    from chat_contents in query,
      where: chat_contents.chat_room_id == ^chat_room_id
  end

  def _search(query, :name, name) do
    from chat_contents in query,
      where: chat_contents.name == ^name
  end

  @spec order(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order(query, nil), do: query

  def order(query, "Newest first") do
    from chat_contents in query,
      order_by: [desc: chat_contents.inserted_at, desc: chat_contents.id]
  end

  def order(query, "Oldest first") do
    from chat_contents in query,
      order_by: [asc: chat_contents.inserted_at, asc: chat_contents.id]
  end

  @spec preload(Ecto.Query.t(), list | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :users in preloads, do: _preload_users(query), else: query

    query
  end

  def _preload_users(query) do
    from chat_contents in query,
      left_join: users in assoc(chat_contents, :user),
      preload: [user: users]
  end
end
