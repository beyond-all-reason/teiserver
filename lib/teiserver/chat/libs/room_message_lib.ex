defmodule Teiserver.Chat.RoomMessageLib do
  use CentralWeb, :library
  alias Teiserver.Chat.RoomMessage

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-???"

  @spec colours :: atom
  def colours, do: :default

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(room_message) do
    %{
      type_colour: StylingHelper.colours(colours()) |> elem(0),
      type_icon: icon(),

      item_id: room_message.id,
      item_type: "teiserver_chat_room_message",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Chat.RoomMessageLib.icon(),
      item_label: "#{room_message.name}",

      url: "/chat/room_messages/#{room_message.id}"
    }
  end

  # Queries
  @spec query_room_messages() :: Ecto.Query.t
  def query_room_messages do
    from room_messages in RoomMessage
  end

  @spec search(Ecto.Query.t, Map.t | nil) :: Ecto.Query.t
  def search(query, nil), do: query
  def search(query, params) do
    params
    |> Enum.reduce(query, fn ({key, value}, query_acc) ->
      _search(query_acc, key, value)
    end)
  end

  @spec _search(Ecto.Query.t, Atom.t(), any()) :: Ecto.Query.t
  def _search(query, _, ""), do: query
  def _search(query, _, nil), do: query

  def _search(query, :id, id) do
    from room_messages in query,
      where: room_messages.id == ^id
  end

  def _search(query, :user_id, user_id) do
    from room_messages in query,
      where: room_messages.user_id == ^user_id
  end

  def _search(query, :id_list, id_list) do
    from room_messages in query,
      where: room_messages.id in ^id_list
  end

  def _search(query, :basic_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from room_messages in query,
      where: (
            ilike(room_messages.name, ^ref_like)
        )
  end

  def _search(query, :term, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from room_messages in query,
      where: (
            ilike(room_messages.content, ^ref_like)
        )
  end

  def _search(query, :inserted_after, timestamp) do
    from room_messages in query,
      where: room_messages.inserted_at >= ^timestamp
  end

  def _search(query, :inserted_before, timestamp) do
    from room_messages in query,
      where: room_messages.inserted_at < ^timestamp
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from room_messages in query,
      order_by: [asc: room_messages.name]
  end

  def order_by(query, "Name (Z-A)") do
    from room_messages in query,
      order_by: [desc: room_messages.name]
  end

  def order_by(query, "Newest first") do
    from room_messages in query,
      order_by: [desc: room_messages.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from room_messages in query,
      order_by: [asc: room_messages.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, preloads) do
    query = if :user in preloads, do: _preload_users(query), else: query
    query
  end

  def _preload_users(query) do
    from room_messages in query,
      left_join: users in assoc(room_messages, :user),
      preload: [user: users]
  end
end
