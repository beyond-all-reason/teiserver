defmodule Teiserver.Chat.LobbyMessageLib do
  @moduledoc false
  use TeiserverWeb, :library
  alias Teiserver.Chat.LobbyMessage

  # Functions
  @spec icon :: String.t()
  def icon, do: "fa-solid fa-comment"

  @spec colours :: atom
  def colours, do: :primary2

  # Queries
  @spec query_lobby_messages() :: Ecto.Query.t()
  def query_lobby_messages do
    from(lobby_messages in LobbyMessage)
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
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from lobby_messages in query,
      where: lobby_messages.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from lobby_messages in query,
      where: lobby_messages.user_id == ^user_id
  end

  def _search(query, :user_id_in, []), do: query

  def _search(query, :user_id_in, id_list) do
    from lobby_messages in query,
      where: lobby_messages.user_id in ^id_list
  end

  def _search(query, :user_id_not_in, id_list) do
    from lobby_messages in query,
      where: lobby_messages.user_id not in ^id_list
  end

  def _search(query, :match_id, match_id) do
    from lobby_messages in query,
      where: lobby_messages.match_id == ^match_id
  end

  def _search(query, :match_id_in, match_ids) do
    from lobby_messages in query,
      where: lobby_messages.match_id in ^match_ids
  end

  def _search(query, :id_list, id_list) do
    from lobby_messages in query,
      where: lobby_messages.id in ^id_list
  end

  def _search(query, :term, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from lobby_messages in query,
      where: ilike(lobby_messages.content, ^ref_like)
  end

  def _search(query, :inserted_after, timestamp) do
    from lobby_messages in query,
      where: lobby_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from lobby_messages in query,
      where: lobby_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t(), String.t() | nil) :: Ecto.Query.t()
  def order_by(query, nil), do: query

  def order_by(query, "Name (A-Z)") do
    from lobby_messages in query,
      order_by: [asc: lobby_messages.name]
  end

  def order_by(query, "Name (Z-A)") do
    from lobby_messages in query,
      order_by: [desc: lobby_messages.name]
  end

  def order_by(query, "Newest first") do
    from lobby_messages in query,
      order_by: [desc: lobby_messages.inserted_at, desc: lobby_messages.id]
  end

  def order_by(query, "Oldest first") do
    from lobby_messages in query,
      order_by: [asc: lobby_messages.inserted_at, asc: lobby_messages.id]
  end

  @spec preload(Ecto.Query.t(), List.t() | nil) :: Ecto.Query.t()
  def preload(query, nil), do: query

  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_users(query) do
    from lobby_messages in query,
      left_join: users in assoc(lobby_messages, :user),
      preload: [user: users]
  end
end
