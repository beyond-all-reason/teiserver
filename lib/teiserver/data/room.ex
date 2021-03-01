defmodule Teiserver.Room do
  @moduledoc false
  require Logger
  alias Phoenix.PubSub

  def create_room(%{name: _} = room) do
    Map.merge(
      %{
        members: [],
        password: ""
      },
      room
    )
  end

  def create_room(room_name, author_id) do
    %{
      name: room_name,
      members: [],
      author_id: author_id,
      topic: "topic",
      password: ""
    }
  end

  def get_room(name) do
    ConCache.get(:rooms, name)
  end

  def get_or_make_room(name, author_id) do
    case ConCache.get(:rooms, name) do
      nil ->
        # No room, we need to make one!
        create_room(name, author_id)
        |> add_room

      room ->
        room
    end
  end

  def add_user_to_room(user_id, room_name) do
    ConCache.update(:rooms, room_name, fn room_state ->
      new_state =
        if Enum.member?(room_state.members, user_id) do
          # No change takes place, they're already in the room!
          room_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:add_user_to_room, user_id, room_name}
          )

          new_members = room_state.members ++ [user_id]
          Map.put(room_state, :members, new_members)
        end

      {:ok, new_state}
    end)
  end

  def remove_user_from_room(user_id, room_name) do
    ConCache.update(:rooms, room_name, fn room_state ->
      new_state =
        if not Enum.member?(room_state.members, user_id) do
          # No change takes place, they've already left the room
          room_state
        else
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:remove_user_from_room, user_id, room_name}
          )

          new_members = Enum.filter(room_state.members, fn m -> m != user_id end)
          Map.put(room_state, :members, new_members)
        end

      {:ok, new_state}
    end)
  end

  def add_room(room) do
    ConCache.put(:rooms, room.name, room)

    ConCache.update(:lists, :rooms, fn value ->
      new_value =
        (value ++ [room.name])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    room
  end

  def list_rooms() do
    ConCache.get(:lists, :rooms)
    |> Enum.map(fn room_name -> ConCache.get(:rooms, room_name) end)
  end

  def send_message(from, room_name, msg) do
    case get_room(room_name) do
      nil ->
        nil

      room ->
        if from in room.members do
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:new_message, from, room_name, msg}
          )
        end
    end
  end

  def send_message_ex(from, room_name, msg) do
    case get_room(room_name) do
      nil ->
        nil

      room ->
        if from in room.members do
          PubSub.broadcast(
            Central.PubSub,
            "room:#{room_name}",
            {:new_message_ex, from, room_name, msg}
          )
        end
    end
  end
end
