defmodule Teiserver.Data.UserTest do
  use Central.ServerCase
  alias Teiserver.{User, Account}
  alias Teiserver.TeiserverTestLib

  test "adding two bots with the same email" do
    # Spring protocol runs on usernames while this runs on emails as the unique
    # field for users. As such it is possible for there to be a clash.

    # This is our base user that will create other users
    base_user = TeiserverTestLib.new_user("twobot_test_base1", %{"moderator" => true})

    user1 = User.register_bot("twobot_test_base1[01]", base_user.id)
    user2 = User.register_bot("twobot_test_base1[02]", base_user.id)

    # Now try to register them again
    user1b = User.register_bot("twobot_test_base1[01]", base_user.id)

    assert user1.id == user1b.id
    assert user1.id != user2.id
  end

  test "registering a duplicate user" do
    result = User.register_user_with_md5("dupe_name", "dupe@email.e", "md5_password", "ip")
    assert result == :success

    result = User.register_user_with_md5("DUPE_NAME", "DUPE@email.e", "md5_password", "ip")
    assert result == {:error, "Username already taken"}

    result = User.register_user_with_md5("non_dupe_name", "DUPE@email.e", "md5_password", "ip")
    assert result == {:error, "Email already attached to a user (DUPE@email.e)"}
  end

  # We will now be calculating ranks based on
  # test "calculate rank" do
  #   user = TeiserverTestLib.new_user()
  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 60,
  #     "spectator_minutes" => 60 * 60
  #   })
  #   assert User.calculate_rank(user.id) == 3

  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 1,
  #     "spectator_minutes" => 60 * 1
  #   })
  #   assert User.calculate_rank(user.id) == 0

  #   Account.update_user_stat(user.id, %{
  #     "player_minutes" => 60 * 240,
  #     "spectator_minutes" => 0
  #   })
  #   assert User.calculate_rank(user.id) == 4
  # end

  test "renaming" do
    user = TeiserverTestLib.new_user()

    assert User.rename_user(user.id, "rename1") == :success
    assert User.rename_user(user.id, "rename2") == :success

    assert User.rename_user(user.id, "rename3") ==
             {:error,
              "If you keep changing your name people won't know who you are; give it a bit of time (5 days)"}

    # Lets make it so they can do it again
    Account.update_user_stat(user.id, %{
      "rename_log" => [0]
    })

    assert User.rename_user(user.id, "rename4") == :success
    assert User.rename_user(user.id, "rename44") == :success

    assert User.rename_user(user.id, "rename5") ==
             {:error,
              "If you keep changing your name people won't know who you are; give it a bit of time (5 days)"}

    # What if they've done it many times before but nothing recent?
    Account.update_user_stat(user.id, %{
      "rename_log" => [0, 5, 10]
    })

    assert User.rename_user(user.id, "rename6") == :success
    assert User.rename_user(user.id, "rename66") == :success

    assert User.rename_user(user.id, "rename7") ==
             {:error,
              "If you keep changing your name people won't know who you are; give it a bit of time (5 days)"}

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

    assert User.rename_user(user.id, "rename8") ==
             {:error,
              "If you keep changing your name people won't know who you are; give it a bit of time (30 days)"}
  end

  test "valid_email?" do
    data = [
      {"name@domain.com", true},
      {"name.name@domain.co.uk", true},
      {"name@domain", false},
      {"name.domain", false},
      {"name", false}
    ]

    for {value, expected} <- data do
      result = User.valid_email?(value)
      assert result == expected, message: "Bad result for email '#{value}'"
    end
  end
end
