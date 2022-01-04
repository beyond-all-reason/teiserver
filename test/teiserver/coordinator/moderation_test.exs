defmodule Teiserver.Coordinator.ModerationTest do
  use Central.ServerCase, async: false
  alias Teiserver.{User, Coordinator, Client}

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0, tachyon_auth_setup: 1, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Teiserver.Coordinator.start_coordinator()
    user = new_user()
    moderator = new_user()
    {:ok, user: user, moderator: moderator}
  end

  test "login with warning", %{user: user, moderator: moderator} do
    refute User.is_warned?(user.id)
    refute User.is_muted?(user.id)
    refute User.is_banned?(user.id)

    {:ok, report} = Central.Account.create_report(%{
      "location" => "battle-lobby",
      "location_id" => nil,
      "reason" => "login_with_warning_test",
      "reporter_id" => moderator.id,
      "target_id" => user.id,
      "response_text" => "login_with_warning_test",
      "response_action" => "Warn",
      "expires" => Timex.now |> Timex.shift(days: 1),
      "responder_id" => moderator.id
    })
    User.create_report(report.id)

    # Did it take?
    assert User.is_warned?(user.id)
    refute User.is_muted?(user.id)
    refute User.is_banned?(user.id)
    refute Client.is_shadowbanned?(user.id)

    # Now login
    %{socket: socket} = tachyon_auth_setup(user)
    :timer.sleep(200)

    [_, expires] = User.get_user_by_id(user.id).warned
    [msg] = _tachyon_recv(socket)
    assert msg == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => [
        "This is a reminder that you recently received one or more formal warnings as listed below, the warnings expire #{expires}.",
        " - login_with_warning_test",
        "Acknowledge this with 'I acknowledge this' to resume play"
      ],
      "sender_id" => Coordinator.get_coordinator_userid()
    }

    assert Client.is_shadowbanned?(user.id)

    # Send something back
    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => Coordinator.get_coordinator_userid(),
      "message" => "Nope nope nope"
    })
    :timer.sleep(200)
    [msg] = _tachyon_recv(socket)
    assert msg == %{"cmd" => "s.lobby.send_direct_message", "result" => "success"}

    [msg] = _tachyon_recv(socket)
    assert msg == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => "I don't currently handle messages, sorry #{user.name}",
      "sender_id" => Coordinator.get_coordinator_userid()
    }
    assert Client.is_shadowbanned?(user.id)

    # Now send back the correct response
    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => Coordinator.get_coordinator_userid(),
      "message" => "I acknowledge this"
    })
    _ = _tachyon_recv(socket)
    [msg] = _tachyon_recv(socket)
    assert msg == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => "Thank you",
      "sender_id" => Coordinator.get_coordinator_userid()
    }
    refute Client.is_shadowbanned?(user.id)
  end
end
