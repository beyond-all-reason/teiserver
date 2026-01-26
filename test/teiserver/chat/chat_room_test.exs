defmodule Teiserver.Chat.ChatRoomTest do
  use Teiserver.DataCase

  alias Phoenix.PubSub
  alias Teiserver.Room
  alias Teiserver.Chat

  setup do
    :ok = Supervisor.terminate_child(Teiserver.Supervisor, Teiserver.Chat.RoomSystem)
    {:ok, _pid} = Supervisor.restart_child(Teiserver.Supervisor, Teiserver.Chat.RoomSystem)
    user = Central.Helpers.GeneralTestLib.make_user(%{"data" => %{"roles" => ["Verified"]}})

    {:ok, user: user}
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

  test "invalid user can't join room", ctx do
    name = "room name"
    Room.get_or_make_room(name, ctx.user.id)
    assert Room.can_join_room?(-12_389, name) == {false, "No user"}
  end

  test "valid user can join room", ctx do
    name = "room name"
    Room.get_or_make_room(name, ctx.user.id)
    assert Room.can_join_room?(ctx.user.id, name) == true
  end

  test "can join new room (also create the room as side effect)", ctx do
    assert Room.can_join_room?(ctx.user.id, "new room") == true
    %{name: "new room"} = Room.get_room("new room")
  end

  test "can remove room" do
    name = "room name"
    Room.get_or_make_room(name, 123)
    :ok = Room.remove_room(name)
    assert Room.get_room(name) == nil
  end

  test "removing non existing room is fine" do
    assert :ok == Room.remove_room("no room")
  end

  test "can leave room" do
    name = "room name"
    PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
    Room.get_or_make_room(name, 123)
    Room.add_user_to_room(123, name)
    assert_received {:add_user_to_room, 123, ^name}

    Room.remove_user_from_room(123, name)
    assert_received {:remove_user_from_room, 123, ^name}
    assert Room.list_rooms() == [{name, 0}]
  end

  test "leaving room twice doesn't send multiple messages" do
    name = "room name"
    PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
    Room.get_or_make_room(name, 123)
    Room.add_user_to_room(123, name)
    assert_received {:add_user_to_room, 123, ^name}

    Room.remove_user_from_room(123, name)
    assert_received {:remove_user_from_room, 123, ^name}
    Room.remove_user_from_room(123, name)
    refute_received {:remove_user_from_room, 123, ^name}
  end

  test "user is removed from room automatically" do
    sink_task =
      Task.async(fn ->
        receive do
          _x -> nil
        end
      end)

    name = "room name"
    Room.get_or_make_room(name, 123)
    Room.add_user_to_room(123, name, sink_task.pid)

    send(sink_task.pid, nil)
    Task.await(sink_task)
    room = Room.get_room(name)
    assert not MapSet.member?(room.members, 123)
    assert Room.list_rooms() == [{name, 0}]
  end

  describe "send_message" do
    test "can send message", ctx do
      name = "room name"
      Room.get_or_make_room(name, ctx.user.id)
      Room.add_user_to_room(ctx.user.id, name)
      PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
      PubSub.subscribe(Teiserver.PubSub, "room_chat")

      Room.send_message(ctx.user.id, name, "message!")

      user_id = ctx.user.id
      assert_receive {:new_message, ^user_id, ^name, "message!"}
      assert Chat.get_room_message!(nil, search: [chat_room: name]).content == "message!"
    end

    test "can send multiple messages", ctx do
      name = "room name"
      Room.get_or_make_room(name, ctx.user.id)
      Room.add_user_to_room(ctx.user.id, name)
      PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
      PubSub.subscribe(Teiserver.PubSub, "room_chat:#{name}")

      Room.send_message(ctx.user.id, name, ["message1", "message2"])

      user_id = ctx.user.id
      assert_receive {:new_message, ^user_id, ^name, "message1"}
      assert_receive {:new_message, ^user_id, ^name, "message2"}
      [msg1, msg2] = Chat.list_room_messages(search: [chat_room: name])
      assert MapSet.new([msg1.content, msg2.content]) == MapSet.new(["message1", "message2"])

      assert_receive %{channel: "room_chat", event: :message_received, room_name: ^name}
      assert_receive %{channel: "room_chat", event: :message_received, room_name: ^name}
    end

    test "only member can send message", ctx do
      name = "room name"
      PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
      PubSub.subscribe(Teiserver.PubSub, "room_chat")
      Room.get_or_make_room(name, ctx.user.id)
      Room.send_message(ctx.user.id, name, "message!")
      refute_receive {:new_message, _, _, _}
    end
  end

  describe "send_message_ex" do
    test "can send message", ctx do
      name = "room name"
      PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
      Room.get_or_make_room(name, ctx.user.id)
      Room.add_user_to_room(ctx.user.id, name)
      Room.send_message_ex(ctx.user.id, name, "message!")

      user_id = ctx.user.id
      assert_receive {:new_message_ex, ^user_id, ^name, "message!"}
      msg = Chat.get_room_message!(nil, search: [chat_room: name])
      assert msg.user_id == user_id
      assert msg.content == "message!"
    end

    test "only member can send message", ctx do
      name = "room name"
      PubSub.subscribe(Teiserver.PubSub, "room:#{name}")
      Room.get_or_make_room(name, ctx.user.id)
      Room.send_message_ex(ctx.user.id, name, "message!")
      refute_receive {:new_message_ex, _, _, _}
    end
  end
end
