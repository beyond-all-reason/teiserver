defmodule Teiserver.Account.RelationshipLibTest do
  use Teiserver.DataCase, async: true

  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Account.RelationshipLib
  alias Teiserver.Config

  test "purging inactive relationships" do
    # Create two accounts
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    old_login = DateTime.add(Timex.now(), -32, :day)

    user3 =
      AccountTestLib.user_fixture(%{
        "last_login" => old_login
      })

    assert user1.id != nil
    assert user2.id != nil
    assert user3.id != nil

    {:ok, _} = RelationshipLib.avoid_user(user1.id, user2.id)
    {:ok, _} = RelationshipLib.avoid_user(user1.id, user3.id)

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
    {:ok, _} = RelationshipLib.ignore_user(user1.id, user2.id)
    {:ok, _} = RelationshipLib.ignore_user(user1.id, user3.id)

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

  test "ignore_user respects limits" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 2
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    user4 = AccountTestLib.user_fixture()

    # Add users up to the limit
    {:ok, _} = RelationshipLib.ignore_user(user1.id, user2.id)
    {:ok, _} = RelationshipLib.ignore_user(user1.id, user3.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _} = RelationshipLib.check_relationship_limit(user1.id, :ignore, limit)

    # Try to add another ignore - should fail due to limit
    assert {:error, _} = RelationshipLib.ignore_user(user1.id, user4.id)
  end

  test "avoid_user respects limits" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 2
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    user4 = AccountTestLib.user_fixture()

    # Add users up to the limit
    {:ok, _} = RelationshipLib.avoid_user(user1.id, user2.id)
    {:ok, _} = RelationshipLib.avoid_user(user1.id, user3.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _} = RelationshipLib.check_relationship_limit(user1.id, :avoid, limit)

    # Try to add another avoid - should fail due to limit
    assert {:error, _} = RelationshipLib.avoid_user(user1.id, user4.id)
  end

  test "block_user respects limits" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 2
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    user4 = AccountTestLib.user_fixture()

    # Add users up to the limit
    {:ok, _} = RelationshipLib.block_user(user1.id, user2.id)
    {:ok, _} = RelationshipLib.block_user(user1.id, user3.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _} = RelationshipLib.check_relationship_limit(user1.id, :block, limit)

    # Try to add another block - should fail due to limit
    assert {:error, _} = RelationshipLib.block_user(user1.id, user4.id)
  end

  test "check_relationship_limit function works correctly" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 1
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()

    # Test under limit (0 relationships with limit of 1 should be ok)
    assert :ok = RelationshipLib.check_relationship_limit(user1.id, :ignore, limit)

    # Test over limit (after adding some relationships)
    {:ok, _} = RelationshipLib.ignore_user(user1.id, user2.id)
    assert {:error, _} = RelationshipLib.check_relationship_limit(user1.id, :ignore, limit)
  end
end
