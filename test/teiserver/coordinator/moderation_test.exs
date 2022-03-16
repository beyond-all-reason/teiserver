defmodule Teiserver.Coordinator.ModerationTest do
  use Central.ServerCase, async: false
  alias Teiserver.{User, Coordinator, Client}
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0, tachyon_auth_setup: 1, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
    user = new_user()
    moderator = new_user()
    {:ok, user: user, moderator: moderator}
  end

  test "login with warning", %{user: user, moderator: moderator} do
    delay = Central.Config.get_site_config_cache("teiserver.Post login action delay")

    refute User.has_warning?(user.id)
    refute User.has_mute?(user.id)
    refute User.is_restricted?(user.id, ["Login"])

    {:ok, report} = Central.Account.create_report(%{
      "location" => "battle-lobby",
      "location_id" => nil,
      "reason" => "login_with_warning_test",
      "reporter_id" => moderator.id,
      "target_id" => user.id,
      "response_text" => "login_with_warning_test",
      "response_action" => "Restrict",
      "action_data" => %{"restriction_list" => ["Warning reminder"]},
      "followup" => "Additional actions",
      "code_refernces" => ["1.1", "2.2"],
      "expires" => Timex.now |> Timex.shift(days: 1),
      "responder_id" => moderator.id
    })

    User.create_report(report, :create)
    # Need to allow time for it to propagate
    :timer.sleep(200)

    # Did it take?
    assert User.has_warning?(user.id)
    refute User.has_mute?(user.id)
    refute User.is_restricted?(user.id, ["Login"])

    # Now login
    %{socket: socket} = tachyon_auth_setup(user)
    :timer.sleep(200 + delay)

    expires = date_to_str(report.expires, format: :ymd_hms)
    [msg] = _tachyon_recv(socket)
    assert msg == %{
      "cmd" => "s.communication.received_direct_message",
      "message" => [
        "This is a reminder that you received one or more formal moderation actions as listed below:",
        " - login_with_warning_test, expires #{expires}",
        "If the behaviour continues one or more of the following actions may be performed:",
        "- Additional actions",
        "If you feel that you have been the target of an erroneous or unjust moderation action please contact the head of moderation, Beherith",
        "Acknowledge this with 'I acknowledge this' to resume play"
      ],
      "sender_id" => Coordinator.get_coordinator_userid()
    }

    client = Client.get_client_by_id(user.id)
    assert client.awaiting_warn_ack

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
    client = Client.get_client_by_id(user.id)
    assert client.awaiting_warn_ack

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
    client = Client.get_client_by_id(user.id)
    refute client.awaiting_warn_ack
  end
end
