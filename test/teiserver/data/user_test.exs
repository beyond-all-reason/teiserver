defmodule Teiserver.Data.UserTest do
  use Central.ServerCase
  alias Teiserver.User
  alias Teiserver.TestLib

  test "adding two bots with the same email" do
    # Spring protocol runs on usernames while this runs on emails as the unique
    # field for users. As such it is possible for there to be a clash.

    # This is our base user that will create other users
    base_user = TestLib.new_user("twobot_test_base1", %{"moderator" => true})

    user1 = User.register_bot("twobot_test_base1[01]", base_user.id)
    user2 = User.register_bot("twobot_test_base1[02]", base_user.id)

    # Now try to register them again
    user1b = User.register_bot("twobot_test_base1[01]", base_user.id)

    assert user1.id == user1b.id
    assert user1.id != user2.id
  end
end
