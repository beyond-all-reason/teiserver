defmodule Teiserver.Coordinator.CoordinatorCommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.{User, Coordinator}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: socket, user: user} = tachyon_auth_setup()

    coordinator_userid = Coordinator.get_coordinator_userid()

    {:ok, socket: socket, user: user, coordinator_userid: coordinator_userid}
  end

  test "no command", %{socket: socket} do
    message_coordinator(socket, "$no_command_here or here")
    [reply] = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.lobby.send_direct_message", "result" => "success"}

    # It's not a valid command and thus we ignore it currently
    reply = _tachyon_recv(socket)
    assert reply == :timeout
  end

  test "mute user command", %{socket: socket, user: user, coordinator_userid: coordinator_userid} do
    %{user: user2} = tachyon_auth_setup()

    message_coordinator(socket, "$mute #{user2.name}")
    [reply] = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.lobby.send_direct_message", "result" => "success"}

    # It's not a valid command and thus we ignore it currently
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => "#{user2.name} is now ignored, you can unmute them with the $unignore command or via the relationships section of the website.",
      "sender_id" => coordinator_userid
    }

    user = User.get_user_by_id(user.id)
    assert user.ignored == [user2.id]

    # Now use it again, make sure we don't get a crash
    message_coordinator(socket, "$unmute #{user2.name}")
    [reply] = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.lobby.send_direct_message", "result" => "success"}

    # It's not a valid command and thus we ignore it currently
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => "#{user2.name} is now un-ignored.",
      "sender_id" => coordinator_userid
    }

    user = User.get_user_by_id(user.id)
    assert user.ignored == []

    # Now unmute again
    message_coordinator(socket, "$unmute #{user2.name}")
    [reply] = _tachyon_recv(socket)
    assert reply == %{"cmd" => "s.lobby.send_direct_message", "result" => "success"}

    # It's not a valid command and thus we ignore it currently
    [reply] = _tachyon_recv(socket)
    assert reply == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => "#{user2.name} is now un-ignored.",
      "sender_id" => coordinator_userid
    }

    user = User.get_user_by_id(user.id)
    assert user.ignored == []
  end

  defp message_coordinator(socket, message) do
    _tachyon_send(socket, %{
      cmd: "c.communication.send_direct_message",
      message: message,
      recipient_id: Coordinator.get_coordinator_userid()
    })
  end
end
