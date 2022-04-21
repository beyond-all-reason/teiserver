defmodule Teiserver.Coordinator.MatchMonitorServerTest do
  use Central.ServerCase, async: false
  alias Teiserver.{User}
  alias Teiserver.Coordinator.{CoordinatorServer}

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0, tachyon_auth_setup: 1, _tachyon_send: 2]

  setup do
    account = CoordinatorServer.get_coordinator_account()
    Central.cache_put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    Teiserver.Battle.start_match_monitor()

    user = new_user()
    User.update_user(%{user | bot: true})
    %{socket: socket} = tachyon_auth_setup(user)

    user2 = new_user()

    {:ok, user: user, user2: user2, socket: socket}
  end

  test "end game data", %{user: user} do

  end

  test "chat messages", %{socket: socket, user: user, user2: user2} do
    monitor_user = User.get_user_by_name("AutohostMonitor")

    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{user2.name}> a: Allied chat message"
    })

    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{user2.name}> g: Game chat message"
    })

    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{user2.name}> s: Spec chat message"
    })

    _tachyon_send(socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{user2.name}> d123: Direct chat message"
    })
  end
end
