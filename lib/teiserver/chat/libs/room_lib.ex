defmodule Teiserver.Chat.RoomLib do
  use CentralWeb, :library
  alias Teiserver.Chat.Room

  # Functions
  @spec icon :: String.t()
  def icon, do: "far fa-???"
  @spec colours :: {String.t(), String.t(), String.t()}
  def colours, do: Central.Helpers.StylingHelper.colours(:default)

  @spec make_favourite(Map.t()) :: Map.t()
  def make_favourite(room) do
    %{
      type_colour: colours() |> elem(0),
      type_icon: icon(),

      item_id: room.id,
      item_type: "teiserver_chat_room",
      item_colour: colours() |> elem(0),
      item_icon: Teiserver.Chat.RoomLib.icon(),
      item_label: "#{room.name}",

      url: "/chat/rooms/#{room.id}"
    }
  end

  # Queries
  @spec query_rooms() :: Ecto.Query.t
  def query_rooms do
    from rooms in Room
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
    from rooms in query,
      where: rooms.id == ^id
  end

  def _search(query, :name, name) do
    from rooms in query,
      where: rooms.name == ^name
  end

  def _search(query, :id_list, id_list) do
    from rooms in query,
      where: rooms.id in ^id_list
  end

  def _search(query, :simple_search, ref) do
    ref_like = "%" <> String.replace(ref, "*", "%") <> "%"

    from rooms in query,
      where: (
            ilike(rooms.name, ^ref_like)
        )
  end

  @spec order_by(Ecto.Query.t, String.t | nil) :: Ecto.Query.t
  def order_by(query, nil), do: query
  def order_by(query, "Name (A-Z)") do
    from rooms in query,
      order_by: [asc: rooms.name]
  end

  def order_by(query, "Name (Z-A)") do
    from rooms in query,
      order_by: [desc: rooms.name]
  end

  def order_by(query, "Newest first") do
    from rooms in query,
      order_by: [desc: rooms.inserted_at]
  end

  def order_by(query, "Oldest first") do
    from rooms in query,
      order_by: [asc: rooms.inserted_at]
  end

  @spec preload(Ecto.Query.t, List.t | nil) :: Ecto.Query.t
  def preload(query, nil), do: query
  def preload(query, _preloads) do
    # query = if :things in preloads, do: _preload_things(query), else: query
    query
  end

  # def _preload_things(query) do
  #   from rooms in query,
  #     left_join: things in assoc(rooms, :things),
  #     preload: [things: things]
  # end
end
