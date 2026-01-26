defmodule Teiserver.Chat.ChatRoomTest do
  use Teiserver.DataCase

  alias Phoenix.PubSub
  alias Teiserver.Room

  setup do
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, Teiserver.Chat.RoomSystem)
    {:ok, _pid} = Supervisor.restart_child(Teiserver.Supervisor, Teiserver.Chat.RoomSystem)
    :ok
  end

  test "get_room returns nil when no room" do
    assert Room.get_room("that's not a room") == nil
  end

  test "get rooms returns the room" do
    name = "this is a name"
    Room.get_or_make_room(name, 123)
    %{name: ^name} = Room.get_room(name)
  end

  test "create and list rooms" do
    name = "testroom1"
    Room.get_or_make_room(name, 123)
    assert Room.list_rooms() == [{name, 0}]
  end

  test "can join room" do
    name = "room name"
    PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
    Room.get_or_make_room(name, 123)
    Room.add_user_to_room(123, name)
    assert_received {:add_user_to_room, 123, ^name}
    assert Room.list_rooms() == [{name, 1}]
  end

  test "joining twice only triggers one message" do
    name = "room name"
    PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
    Room.get_or_make_room(name, 123)
    Room.add_user_to_room(123, name)
    Room.add_user_to_room(123, name)
    assert_received {:add_user_to_room, 123, ^name}
    refute_received {:add_user_to_roo, _, _}, 10
  end

  test "does nothing on invalid room" do
    name = "room name"
    Room.add_user_to_room(123, name)
    refute_received {:add_user_to_roo, _, _}, 10
  end
end
