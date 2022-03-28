defmodule Teiserver.Coordinator.AutomodTest do
  use Central.ServerCase, async: false
  alias Central.{Config, Logging}
  alias Teiserver.{Account, User, Client}
  alias Teiserver.Coordinator.{CoordinatorServer, AutomodServer}

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0, tachyon_auth_setup: 1, _tachyon_send: 2]

  setup do
    account = CoordinatorServer.get_coordinator_account()
    ConCache.put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    Config.update_site_config("teiserver.Automod action delay", 0)
    banned_user = new_user()
    {:ok, banned_user: banned_user}
  end

  test "hw_ban", %{banned_user: banned_user} do
    {:ok, automod_action} = Account.create_automod_action(%{
      enabled: true,
      type: "hardware",
      value: "uOGXziwWC1mCePGsh0tTQg==",
      added_by_id: banned_user.id,
      user_id: banned_user.id,
      actions: %{},
      reason: "hw-ban"
    })

    good_user = new_user()
    Account.update_user_stat(good_user.id, %{
      "hardware:cpuinfo" => "123",
      "hardware:gpuinfo" => "123",
      "hardware:osinfo" => "123",
      "hardware:raminfo" => "123"
    })

    bad_user = new_user()
    Account.update_user_stat(bad_user.id, %{
      "hardware:cpuinfo" => "xyz",
      "hardware:gpuinfo" => "xyz",
      "hardware:osinfo" => "xyz",
      "hardware:raminfo" => "xyz"
    })

    result = AutomodServer.check_user(good_user.id)
    assert result == "No action"

    result = AutomodServer.check_user(bad_user.id)
    assert result == "Banned user"
    stats = Account.get_user_stat_data(bad_user.id)
    assert stats["autoban_type"] == "hardware"
    assert stats["autoban_id"] == automod_action.id
  end

  test "lobby_hash_ban", %{banned_user: banned_user} do
    {:ok, automod_action} = Account.create_automod_action(%{
      enabled: true,
      type: "lobby_hash",
      value: "123456789 abcdefghij",
      added_by_id: banned_user.id,
      user_id: banned_user.id,
      actions: %{},
      reason: "hw-ban"
    })

    good_user1 = new_user()
    Account.update_user_stat(good_user1.id, %{
      "lobby_hash" => "123456789"
    })

    good_user2 = new_user()
    Account.update_user_stat(good_user2.id, %{
      "lobby_hash" => "abcdefghij"
    })

    good_user3 = new_user()
    Account.update_user_stat(good_user3.id, %{
      "lobby_hash" => "123456789 abcdefghijj"
    })

    bad_user = new_user()
    Account.update_user_stat(bad_user.id, %{
      "lobby_hash" => "123456789 abcdefghij"
    })

    result = AutomodServer.check_user(good_user1.id)
    assert result == "No action"

    result = AutomodServer.check_user(good_user2.id)
    assert result == "No action"

    result = AutomodServer.check_user(good_user3.id)
    assert result == "No action"

    result = AutomodServer.check_user(bad_user.id)
    assert result == "Banned user"
    stats = Account.get_user_stat_data(bad_user.id)
    assert stats["autoban_type"] == "lobby_hash"
    assert stats["autoban_id"] == automod_action.id
  end

  test "delayed data", %{banned_user: banned_user} do
    Teiserver.Battle.MatchMonitorServer.do_start()

    standard_user = new_user()
    %{socket: standard_socket} = tachyon_auth_setup(standard_user)

    bot_user = new_user()
    User.update_user(%{bot_user | bot: true}, persist: true)
    %{socket: bot_socket} = tachyon_auth_setup(bot_user)
    assert User.is_bot?(bot_user.id)

    monitor_user = User.get_user_by_name("AutohostMonitor")

    {:ok, _automod_action} = Account.create_automod_action(%{
      enabled: true,
      type: "hardware",
      value: "uOGXziwWC1mCePGsh0tTQg==",
      added_by_id: banned_user.id,
      user_id: banned_user.id,
      actions: %{},
      reason: "hw-ban"
    })

    delayed_user = new_user()
    %{socket: _delayed_socket} = tachyon_auth_setup(delayed_user)

    result = AutomodServer.check_user(delayed_user.id)
    assert result == "No action"
    stats = Account.get_user_stat_data(delayed_user.id)
    assert match?(%{
      "country" => "??",
      "bot" => false,
      "last_ip" => "127.0.0.1",
      "lobby_hash" => "t1 t2",
      "rank" => 0
    }, stats)
    refute Map.has_key?(stats, "hardware:cpuinfo")

    # Now we send some data from the standard user
    encoded = %{
      "username" => delayed_user.name,
      "CPU" => "xyz",
      "GPU" => "xyz",
      "OS" => "xyz",
      "RAM" => "xyz"
    }
      |> Jason.encode!()
      |> :zlib.compress()
      |> Base.url_encode64()

    _tachyon_send(standard_socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "user_info " <> encoded
    })
    :timer.sleep(200)

    # Should be no update
    stats = Account.get_user_stat_data(delayed_user.id)
    refute Map.has_key?(stats, "hardware:cpuinfo")

    # Should still be connected
    refute Client.get_client_by_id(delayed_user.id) == nil

    # Now send from a bot user
    _tachyon_send(bot_socket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "user_info " <> encoded
    })

    # Should be a key now!
    stats = Account.get_user_stat_data(delayed_user.id)
    assert Map.has_key?(stats, "hardware:cpuinfo")

    # Should also have an automod report against them
    [log] = Logging.list_audit_logs(search: [
      actions: [
          "Teiserver:Automod action enacted",
        ],
      details_equal: {"target_user_id", delayed_user.id |> to_string}
      ],
      order_by: "Newest first"
    )
    report_id = log.details["report_id"]

    report = Account.get_report!(report_id)
    User.update_report(report, "any reason")

    # And disconnected
    assert Client.get_client_by_id(delayed_user.id) == nil
  end
end
