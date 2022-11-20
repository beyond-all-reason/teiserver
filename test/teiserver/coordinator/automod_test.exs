defmodule Teiserver.Coordinator.AutomodTest do
  use Central.ServerCase, async: false
  alias Central.{Config, Logging}
  alias Teiserver.{Account, User, Client, Moderation}
  alias Teiserver.Coordinator.{CoordinatorServer, AutomodServer}
  alias Teiserver.Account.CalculateSmurfKeyTask

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0, tachyon_auth_setup: 1, _tachyon_send: 2]

  setup do
    account = CoordinatorServer.get_coordinator_account()
    Central.cache_put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    Teiserver.Coordinator.AutomodServer.start_automod_server()

    Config.update_site_config("teiserver.Automod action delay", 0)
    banned_user = new_user()
    {:ok, banned_user: banned_user}
  end

  test "hw_ban", %{banned_user: banned_user} do
    {:ok, ban} = Moderation.create_ban(%{
      enabled: true,
      key_values: ["uOGXziwWC1mCePGsh0tTQg==", "some_other_value"],
      added_by_id: banned_user.id,
      source_id: banned_user.id,
      reason: "hw-ban"
    })

    good_user = new_user()
    good_stats = %{
      "hardware:cpuinfo" => "123",
      "hardware:gpuinfo" => "123",
      "hardware:osinfo" => "123",
      "hardware:raminfo" => "123",
      "hardware:displaymax" => "123"
    }

    hw1 = CalculateSmurfKeyTask.calculate_hw1_fingerprint(good_stats)
    hw2 = CalculateSmurfKeyTask.calculate_hw2_fingerprint(good_stats)
    Account.create_smurf_key(good_user.id, "hw1", hw1)
    Account.create_smurf_key(good_user.id, "hw2", hw2)

    :timer.sleep(100)

    bad_user = new_user()
    bad_stats = %{
      "hardware:cpuinfo" => "xyz",
      "hardware:gpuinfo" => "xyz",
      "hardware:osinfo" => "xyz",
      "hardware:raminfo" => "xyz",
      "hardware:displaymax" => "xyz"
    }

    hw1 = CalculateSmurfKeyTask.calculate_hw1_fingerprint(bad_stats)
    hw2 = CalculateSmurfKeyTask.calculate_hw2_fingerprint(bad_stats)
    Account.create_smurf_key(bad_user.id, "hw1", hw1)
    Account.create_smurf_key(bad_user.id, "hw2", hw2)

    result = AutomodServer.check_user(good_user.id)
    assert result == "No action"

    result = AutomodServer.check_user(bad_user.id)
    assert result == "Banned user"
    stats = Account.get_user_stat_data(bad_user.id)
    assert stats["autoban_id"] == ban.id
  end

  test "chobby_hash_ban", %{banned_user: banned_user} do
    {:ok, ban} = Moderation.create_ban(%{
      enabled: true,
      key_values: ["123456789 abcdefghij"],
      added_by_id: banned_user.id,
      source_id: banned_user.id,
      reason: "hw-ban"
    })

    good_user1 = new_user()
    Account.create_smurf_key(good_user1.id, "chobby_hash", "123456789")

    good_user2 = new_user()
    Account.create_smurf_key(good_user2.id, "chobby_hash", "abcdefghij")

    good_user3 = new_user()
    Account.create_smurf_key(good_user3.id, "chobby_hash", "123456789 abcdefghijj")

    bad_user = new_user()
    Account.create_smurf_key(bad_user.id, "chobby_hash", "123456789 abcdefghij")

    result = AutomodServer.check_user(good_user1.id)
    assert result == "No action"

    result = AutomodServer.check_user(good_user2.id)
    assert result == "No action"

    result = AutomodServer.check_user(good_user3.id)
    assert result == "No action"

    result = AutomodServer.check_user(bad_user.id)
    assert result == "Banned user"
    stats = Account.get_user_stat_data(bad_user.id)
    assert stats["autoban_id"] == ban.id
  end

  test "ban added after user", %{banned_user: banned_user} do
    bad_user1 = new_user()
    Account.create_smurf_key(bad_user1.id, "chobby_hash", "123456789")
    :timer.sleep(200)

    {:ok, _ban} = Moderation.create_ban(%{
      enabled: true,
      key_values: ["123456789"],
      added_by_id: banned_user.id,
      source_id: banned_user.id,
      reason: "hw-ban"
    })
    :timer.sleep(200)

    bad_user2 = new_user()
    Account.create_smurf_key(bad_user2.id, "chobby_hash", "123456789")

    # User1 was created before the permaban, they are not banned
    result = AutomodServer.check_user(bad_user1.id)
    assert result == "No action"

    # User2 was created after it, they get banned
    result = AutomodServer.check_user(bad_user2.id)
    assert result == "Banned user"
  end

  test "delayed data", %{banned_user: banned_user} do
    {:ok, _ban} = Moderation.create_ban(%{
      enabled: true,
      key_values: ["uOGXziwWC1mCePGsh0tTQg=="],
      added_by_id: banned_user.id,
      source_id: banned_user.id,
      reason: "hw-ban"
    })

    Teiserver.Battle.MatchMonitorServer.do_start()

    standard_user = new_user()
    %{socket: standard_socket} = tachyon_auth_setup(standard_user)

    bot_user = new_user()
    Account.update_cache_user(bot_user.id, %{bot: true})
    %{socket: bot_socket} = tachyon_auth_setup(bot_user)
    assert User.is_bot?(bot_user.id)

    monitor_user = User.get_user_by_name("AutohostMonitor")

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
    assert Enum.count(Account.list_smurf_keys(search: [user_id: delayed_user.id])) == 1

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
    :timer.sleep(200)

    # Should now have smurf keys
    assert Enum.count(Account.list_smurf_keys(search: [user_id: delayed_user.id])) == 3

    # Should be a key now!
    stats = Account.get_user_stat_data(delayed_user.id)
    assert Map.has_key?(stats, "hardware:cpuinfo")

    # Should also have an automod report against them
    [log] = Logging.list_audit_logs(search: [
      actions: [
          "Moderation:Ban enacted",
        ],
      details_equal: {"target_user_id", delayed_user.id |> to_string}
      ],
      order_by: "Newest first"
    )

    action_id = log.details["action_id"]

    # Ensure it exists
    Moderation.get_action!(action_id)

    # And disconnected
    assert Client.get_client_by_id(delayed_user.id) == nil
  end
end
