defmodule Teiserver.Data.UserTest do
  use Teiserver.ServerCase
  alias Teiserver.{CacheUser, Account}
  alias Teiserver.TeiserverTestLib

  test "adding two bots with the same email" do
    # Spring protocol runs on usernames while this runs on emails as the unique
    # field for users. As such it is possible for there to be a clash.

    # This is our base user that will create other users
    base_user = TeiserverTestLib.new_user("twobot_test_base1")
    base_user = CacheUser.update_user(%{base_user | roles: ["Server", "Moderator"]})

    user1 = CacheUser.register_bot("twobot_test_base1[01]", base_user.id)
    user2 = CacheUser.register_bot("twobot_test_base1[02]", base_user.id)

    # Now try to register them again
    user1b = CacheUser.register_bot("twobot_test_base1[01]", base_user.id)

    assert user1.id == user1b.id
    assert user1.id != user2.id
  end

  @tag :needs_attention
  test "registering a duplicate user" do
    result = CacheUser.register_user_with_md5("dupe_name", "dupe@email.e", "md5_password", "ip")
    assert result == :success

    result = CacheUser.register_user_with_md5("DUPE_NAME", "DUPE@email.e", "md5_password", "ip")
    assert result == {:error, "Username already taken"}

    result =
      CacheUser.register_user_with_md5("non_dupe_name", "DUPE@email.e", "md5_password", "ip")

    assert result == {:error, "Email already attached to a user (DUPE@email.e)"}
  end

  test "registering with empty password" do
    # 1B2M2Y8AsgTpgAmY7PhCfg== md5 hash of empty password Chobby sends
    result =
      CacheUser.register_user_with_md5("name", "name@email.e", "1B2M2Y8AsgTpgAmY7PhCfg==", "ip")

    assert {:error, _} = result
  end

  # We will now be calculating ranks based on
  # test "calculate rank" do
  #   user = TeiserverTestLib.new_user()
  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 60,
  #     "spectator_minutes" => 60 * 60
  #   })
  #   assert CacheUser.calculate_rank(user.id) == 3

  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 1,
  #     "spectator_minutes" => 60 * 1
  #   })
  #   assert CacheUser.calculate_rank(user.id) == 0

  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 240,
  #     "spectator_minutes" => 0
  #   })
  #   assert CacheUser.calculate_rank(user.id) == 4
  # end

  test "renaming" do
    user = TeiserverTestLib.new_user()

    expected_rename_error =
      {:error, "Rename limit reached (2 times in 5 days or 3 times in 30 days)"}

    assert CacheUser.rename_user(user.id, "rename1") == :success
    assert CacheUser.rename_user(user.id, "rename2") == :success

    assert CacheUser.rename_user(user.id, "rename3") == expected_rename_error

    # Lets make it so they can do it again
    Account.update_user_stat(user.id, %{
      "rename_log" => [0]
    })

    assert CacheUser.rename_user(user.id, "rename4") == :success
    assert CacheUser.rename_user(user.id, "rename44") == :success

    assert CacheUser.rename_user(user.id, "rename5") == expected_rename_error

    # What if they've done it many times before but nothing recent?
    Account.update_user_stat(user.id, %{
      "rename_log" => [0, 5, 10]
    })

    assert CacheUser.rename_user(user.id, "rename6") == :success
    assert CacheUser.rename_user(user.id, "rename66") == :success

    assert CacheUser.rename_user(user.id, "rename7") == expected_rename_error

    # Nothing in the last 15 days but enough in the last 30
    now = System.system_time(:second)
    day = 60 * 60 * 24

    Account.update_user_stat(user.id, %{
      "rename_log" => [
        now - day * 10,
        now - day * 11,
        now - day * 12
      ]
    })

    assert CacheUser.rename_user(user.id, "rename8") == expected_rename_error
  end

  test "valid_email?" do
    data = [
      {"name@domain.com", :ok},
      {"name.name@domain.co.uk", :ok},
      {"name@domain", {:error, "invalid email"}},
      {"name.domain", {:error, "invalid email"}},
      {"name", {:error, "invalid email"}}
    ]

    for {value, expected} <- data do
      result = CacheUser.valid_email?(value)
      assert result == expected, message: "Bad result for email '#{value}'"
    end
  end

  test "username symbol restrictions" do
    data = [
      {"abc123", false},
      {"[abc]_123", false},
      {"a_b_c[[123]]", false},
      {"[[__]]", false},
      {"___", true},
      {"[[[", true},
      {"]]]", true},
      {"_abc_123_", true},
      {"[]_[]_[]_", true},
      {"[[[abc123]]]", true}
    ]

    for {value, expected} <- data do
      result = CacheUser.check_symbol_limit(value)
      assert result == expected, message: "Bad result for username '#{value}'"
    end
  end
end
