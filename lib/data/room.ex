defmodule Teiserver.Room do
  alias Phoenix.PubSub

  def create_room(%{name: _} = room) do
    Map.merge(%{
      members: [],
      password: "",
    }, room)
  end

  def create_room(room_name, author) do
    %{
      name: room_name,
      members: [],
      author: author,
      topic: "no topic",
      password: ""
    }
  end
  
  def get_room(name) do
    case ConCache.get(:rooms, name) do
      nil ->
        # No room, we need to make one!
        create_room(name, "no author")
        |> add_room
        
      room -> room
    end
  end

  def add_user_to_room(new_username, room_name) do
    ConCache.update(:rooms, room_name, fn room_state -> 
      new_state = if Enum.member?(room_state.members, new_username) do
        # No change takes place, they're already in the room!
        room_state
      else
        PubSub.broadcast :teiserver_pubsub, "room:#{room_name}", {:add_user, new_username}

        new_members = room_state.members ++ [new_username]
        Map.put(room_state, :members, new_members)
      end

      {:ok, new_state}
    end)
  end

  def remove_user_from_room(username, room_name) do
    ConCache.update(:rooms, room_name, fn room_state -> 
      new_state = if not Enum.member?(room_state.members, username) do
        # No change takes place, they've already left the room
        room_state
      else
        PubSub.broadcast :teiserver_pubsub, "room:#{room_name}", {:remove_user, username}

        new_members = Enum.filter(room_state.members, fn m -> m != username end)
        Map.put(room_state, :members, new_members)
      end

      {:ok, new_state}
    end)
  end

  def add_room(room) do
    ConCache.put(:rooms, room.name, room)
    ConCache.update(:lists, :rooms, fn value -> 
      new_value = (value ++ [room.name])
      |> Enum.uniq

      {:ok, new_value}
    end)
    room
  end
end
