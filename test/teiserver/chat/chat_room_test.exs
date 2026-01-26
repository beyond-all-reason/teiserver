defmodule Teiserver.Chat.ChatRoomTest do
  use Teiserver.DataCase

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
end
