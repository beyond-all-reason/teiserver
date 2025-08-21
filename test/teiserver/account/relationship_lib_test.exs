defmodule Teiserver.Account.RelationshipLibTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Account.RelationshipLib

  test "purging inactive relationships" do
    # Create two accounts
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    old_login = DateTime.add(Timex.now(), -31, :day)

    user3 =
      AccountTestLib.user_fixture(%{
        "last_login" => old_login
      })

    assert user1.id != nil
    assert user2.id != nil
    assert user3.id != nil

    RelationshipLib.avoid_user(user1.id, user2.id)
    RelationshipLib.avoid_user(user1.id, user3.id)

    avoid_list = RelationshipLib.list_userids_avoided_by_userid(user1.id)
    assert Enum.member?(avoid_list, user2.id)
    assert Enum.member?(avoid_list, user3.id)

    # Check count of inactive relationships
    inactive_count = RelationshipLib.get_inactive_ignores_avoids_blocks_count(user1.id, 30)
    assert inactive_count == 1

    # Purge old relationships
    RelationshipLib.delete_inactive_ignores_avoids_blocks(user1.id, 30)

    avoid_list = RelationshipLib.list_userids_avoided_by_userid(user1.id)
    assert Enum.member?(avoid_list, user2.id)
    refute Enum.member?(avoid_list, user3.id)

    # Add users to ignore list
    RelationshipLib.ignore_user(user1.id, user2.id)
    RelationshipLib.ignore_user(user1.id, user3.id)

    # Check ignores
    ignore_list = RelationshipLib.list_userids_ignored_by_userid(user1.id)
    assert Enum.member?(ignore_list, user2.id)
    assert Enum.member?(ignore_list, user3.id)

    # Purge ignores
    RelationshipLib.delete_inactive_ignores_avoids_blocks(user1.id, 30)

    # Check ignores again
    ignore_list = RelationshipLib.list_userids_ignored_by_userid(user1.id)
    assert Enum.member?(ignore_list, user2.id)
    refute Enum.member?(ignore_list, user3.id)
  end
end
