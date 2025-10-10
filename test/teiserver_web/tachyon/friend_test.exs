defmodule TeiserverWeb.Tachyon.FriendTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.Account
  alias Teiserver.Config

  describe "friends" do
    setup [{Tachyon, :setup_client}]

    test "list", ctx1 do
      {:ok, ctx2} = Tachyon.setup_client()
      {:ok, ctx3} = Tachyon.setup_client()
      {:ok, ctx4} = Tachyon.setup_client()
      {:ok, _} = Account.create_friend(ctx1[:user].id, ctx2[:user].id)
      # outgoing
      {:ok, _} = Account.create_friend_request(ctx1[:user].id, ctx3[:user].id)
      # incoming
      {:ok, _} = Account.create_friend_request(ctx4[:user].id, ctx1[:user].id)

      # should not be included
      {:ok, _} = Account.create_friend(ctx3[:user].id, ctx4[:user].id)

      assert %{"status" => "success", "data" => data} = Tachyon.friend_list!(ctx1[:client])

      user1_id = to_string(ctx1[:user].id)
      user2_id = to_string(ctx2[:user].id)
      user3_id = to_string(ctx3[:user].id)
      user4_id = to_string(ctx4[:user].id)

      assert %{
               "friends" => [%{"userId" => ^user2_id}],
               "outgoingPendingRequests" => [%{"to" => ^user3_id}],
               "incomingPendingRequests" => [%{"from" => ^user4_id}]
             } = data

      assert %{"status" => "success", "data" => data} = Tachyon.friend_list!(ctx2[:client])

      assert %{
               "friends" => [%{"userId" => ^user1_id}],
               "outgoingPendingRequests" => [],
               "incomingPendingRequests" => []
             } = data
    end
  end

  test "self event contains friend info" do
    [user1, user2, user3, user4] = Enum.map(1..4, fn _ -> Tachyon.create_user() end)
    {:ok, _} = Account.create_friend(user1.id, user2.id)
    # outgoing
    {:ok, _} = Account.create_friend_request(user1.id, user3.id)
    # incoming
    {:ok, _} = Account.create_friend_request(user4.id, user1.id)

    %{client: client} = Tachyon.connect(user1, swallow_first_event: false)
    %{"commandId" => "user/self", "data" => %{"user" => data}} = Tachyon.recv_message!(client)
    assert data["friendIds"] == [to_string(user2.id)]

    id3 = to_string(user3.id)
    id4 = to_string(user4.id)
    assert [%{"from" => ^id4}] = data["incomingFriendRequest"]
    assert [%{"to" => ^id3}] = data["outgoingFriendRequest"]
  end

  defp setup_friend_requests(_) do
    {:ok, ctx1} = Tachyon.setup_client()
    {:ok, ctx2} = Tachyon.setup_client()
    {:ok, user: ctx1[:user], client: ctx1[:client], user2: ctx2[:user], client2: ctx2[:client]}
  end

  describe "friend request lifecycle" do
    setup :setup_friend_requests

    test "request non-existent user", ctx do
      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.send_friend_request!(ctx[:client], "not-a-valid-id")

      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.send_friend_request!(ctx[:client], "-37189312")
    end

    test "request to self", ctx do
      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user].id)
    end

    test "request to user who ignores sender", ctx do
      Account.ignore_user(ctx[:user2].id, ctx[:user].id)

      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "request to user who avoids sender", ctx do
      Account.avoid_user(ctx[:user2].id, ctx[:user].id)

      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "request when already friends", ctx do
      {:ok, _} = Account.create_friend(ctx[:user].id, ctx[:user2].id)

      assert %{"status" => "failed", "reason" => "already_in_friendlist"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "request when outgoing capacity reached", ctx do
      on_exit(fn ->
        Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
      end)

      limit = 2
      Config.update_site_config("relationships.Maximum relationships per user", limit)

      # Create users to reach the limit
      {:ok, ctx3} = Tachyon.setup_client()
      {:ok, ctx4} = Tachyon.setup_client()

      # Add 2 friends (reaching the limit)
      {:ok, _} = Account.create_friend(ctx[:user].id, ctx3[:user].id)
      {:ok, _} = Account.create_friend(ctx[:user].id, ctx4[:user].id)

      # Try to send a friend request - should fail due to limit
      assert %{"status" => "failed", "reason" => "outgoing_capacity_reached"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "request when incoming capacity reached", ctx do
      on_exit(fn ->
        Teiserver.cache_delete(:config_site_cache, "relationships.Maximum relationships per user")
      end)

      limit = 2
      Config.update_site_config("relationships.Maximum relationships per user", limit)

      # Create users to reach the target's limit
      {:ok, ctx3} = Tachyon.setup_client()
      {:ok, ctx4} = Tachyon.setup_client()

      # Add 2 friends to target user (reaching the limit)
      {:ok, _} = Account.create_friend(ctx[:user2].id, ctx3[:user].id)
      {:ok, _} = Account.create_friend(ctx[:user2].id, ctx4[:user].id)

      # Try to send a friend request - should fail due to target's limit
      assert %{"status" => "failed", "reason" => "incoming_capacity_reached"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "request success", ctx do
      assert %{"status" => "success"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)

      user_id = ctx[:user].id

      assert %Account.FriendRequest{from_user_id: ^user_id} =
               Account.get_friend_request(user_id, ctx[:user2].id)

      expected = %{"from" => to_string(ctx[:user].id)}

      assert %{"commandId" => "friend/requestReceived", "data" => ^expected} =
               Tachyon.recv_message!(ctx[:client2])
    end

    test "mutual requests", ctx do
      assert %{"status" => "success"} =
               Tachyon.send_friend_request!(ctx[:client], ctx[:user2].id)

      %{"commandId" => "friend/requestReceived"} = Tachyon.recv_message!(ctx[:client2])

      assert %{"status" => "success"} =
               Tachyon.send_friend_request!(ctx[:client2], ctx[:user].id)

      %{"commandId" => "friend/requestAccepted"} = Tachyon.recv_message!(ctx[:client])
      %{"commandId" => "friend/requestAccepted"} = Tachyon.recv_message!(ctx[:client2])

      [f1] = Teiserver.Account.list_friends_for_user(%{id: ctx[:user].id})
      assert f1.user1_id == ctx[:user].id || f1.user2_id == ctx[:user2].id
    end

    test "accept from invalid user", ctx do
      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.accept_friend_request!(ctx[:client], "wtfid")
    end

    test "accept non existant request", ctx do
      assert %{"status" => "failed", "reason" => "no_pending_request"} =
               Tachyon.accept_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "can accept friend request", ctx do
      {:ok, _} = Account.create_friend_request(ctx[:user].id, ctx[:user2].id)

      assert %{"status" => "success"} =
               Tachyon.accept_friend_request!(ctx[:client2], ctx[:user].id)

      assert %Account.Friend{} = Account.get_friend(ctx[:user].id, ctx[:user2].id)
      expected = %{"from" => to_string(ctx[:user2].id)}

      assert %{"commandId" => "friend/requestAccepted", "data" => ^expected} =
               Tachyon.recv_message!(ctx[:client])
    end

    test "cancel for invalid user", ctx do
      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.cancel_friend_request!(ctx[:client], "invalid-id")
    end

    test "cancel non existant request", ctx do
      # it's a no-op
      assert %{"status" => "success"} =
               Tachyon.cancel_friend_request!(ctx[:client], ctx[:user2].id)
    end

    test "can cancel request", ctx do
      {:ok, _} = Account.create_friend_request(ctx[:user].id, ctx[:user2].id)

      assert %{"status" => "success"} =
               Tachyon.cancel_friend_request!(ctx[:client], ctx[:user2].id)

      expected = %{"from" => to_string(ctx[:user].id)}

      assert %{"commandId" => "friend/requestCancelled", "data" => ^expected} =
               Tachyon.recv_message!(ctx[:client2])
    end

    test "can't reject non existant request", ctx do
      assert %{"status" => "failed", "reason" => "no_pending_request"} =
               Tachyon.reject_friend_request!(ctx[:client2], ctx[:user].id)
    end

    test "reject request", ctx do
      {:ok, _} = Account.create_friend_request(ctx[:user].id, ctx[:user2].id)

      assert %{"status" => "success"} =
               Tachyon.reject_friend_request!(ctx[:client2], ctx[:user].id)

      assert nil == Account.get_friend(ctx[:user].id, ctx[:user2].id)
      assert nil == Account.get_friend_request(ctx[:user].id, ctx[:user2].id)

      expected = %{"from" => to_string(ctx[:user2].id)}

      assert %{"commandId" => "friend/requestRejected", "data" => ^expected} =
               Tachyon.recv_message!(ctx[:client])
    end
  end

  defp setup_friends(_) do
    {:ok, ctx1} = Tachyon.setup_client()
    {:ok, ctx2} = Tachyon.setup_client()
    {:ok, friend} = Account.create_friend(ctx1[:user].id, ctx2[:user].id)

    {:ok,
     user: ctx1[:user],
     client: ctx1[:client],
     user2: ctx2[:user],
     client2: ctx2[:client],
     friend: friend}
  end

  describe "removing" do
    setup [:setup_friends]

    test "cannot remove non existant user", ctx do
      assert %{"status" => "failed", "reason" => "invalid_user"} =
               Tachyon.remove_friend!(ctx[:client], "lolnope")
    end

    test "is no-op if not friend", ctx do
      random_user = Tachyon.create_user()

      assert %{"status" => "success"} =
               Tachyon.remove_friend!(ctx[:client], random_user.id)
    end

    test "can remove friend", ctx do
      assert %{"status" => "success"} = Tachyon.remove_friend!(ctx[:client], ctx[:user2].id)
      assert nil == Account.get_friend(ctx[:user].id, ctx[:user2].id)
      expected = %{"from" => to_string(ctx[:user].id)}

      assert %{"commandId" => "friend/removed", "data" => ^expected} =
               Tachyon.recv_message!(ctx[:client2])
    end
  end
end
