defmodule Teiserver.Account.FriendRequestLibTest do
  alias Teiserver.Account, as: Account
  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Account.FriendRequest
  alias Teiserver.Account.FriendRequestLib
  alias Teiserver.Account.RelationshipLib
  alias Teiserver.Config
  alias Teiserver.Repo
  use Teiserver.DataCase, async: true

  defp friend_request_fixture(%{id: id}, to), do: friend_request_fixture(id, to)
  defp friend_request_fixture(from, %{id: id}), do: friend_request_fixture(from, id)

  defp friend_request_fixture(from, to) do
    %FriendRequest{}
    |> FriendRequest.changeset(%{from_user_id: from, to_user_id: to})
    |> Repo.insert!()
  end

  test "list requests" do
    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    friend_request_fixture(user1, user2)
    friend_request_fixture(user3, user1)

    assert {[outgoing], [incoming]} = FriendRequestLib.list_requests_for_user(user1.id)
    assert outgoing.from_user_id == user1.id
    assert outgoing.to_user_id == user2.id
    assert incoming.from_user_id == user3.id
    assert incoming.to_user_id == user1.id
  end

  test "friend request limits are enforced" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 2
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    user4 = AccountTestLib.user_fixture()

    # Add 2 friends (reaching the limit)
    {:ok, _friend1} = Account.create_friend(user1.id, user2.id)
    {:ok, _friend2} = Account.create_friend(user1.id, user3.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _reason} = RelationshipLib.check_relationship_limit(user1.id, :friend, limit)

    # Try to send a friend request - should fail due to limit
    assert {:error, _error} = Account.create_friend_request(user1.id, user4.id)
  end

  test "friend counting includes pending requests" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 2
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()
    user4 = AccountTestLib.user_fixture()

    # Add one friend and one pending request (should reach limit of 2)
    {:ok, _friend} = Account.create_friend(user1.id, user2.id)
    {:ok, _request} = Account.create_friend_request(user1.id, user3.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _reason} = RelationshipLib.check_relationship_limit(user1.id, :friend, limit)

    # Try to send another friend request - should fail due to limit
    assert {:error, _error} = Account.create_friend_request(user1.id, user4.id)
  end

  test "friend limits work through create_friend" do
    on_exit(fn ->
      Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
    end)

    limit = 1
    Config.update_site_config("relationships.Maximum relationships per user", limit)

    user1 = AccountTestLib.user_fixture()
    user2 = AccountTestLib.user_fixture()
    user3 = AccountTestLib.user_fixture()

    # Add one friend (reaching limit of 1)
    {:ok, _friend} = Account.create_friend(user1.id, user2.id)

    # Verify we're at the limit using check_relationship_limit
    assert {:error, _reason} = RelationshipLib.check_relationship_limit(user1.id, :friend, limit)

    # Try to create a friend request - should fail due to limit
    assert {:error, _error} = Account.create_friend_request(user1.id, user3.id)
  end
end
