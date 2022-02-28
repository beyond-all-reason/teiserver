defmodule Teiserver.Coordinator.AutomodTest do
  use Central.ServerCase, async: false
  alias Teiserver.Account
  alias Teiserver.Coordinator.AutomodServer

  import Teiserver.TeiserverTestLib,
    only: [new_user: 0]

  setup do
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
end
