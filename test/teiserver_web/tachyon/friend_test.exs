defmodule TeiserverWeb.Tachyon.FriendTest do
  use TeiserverWeb.ConnCase
  alias Teiserver.Support.Tachyon
  alias Teiserver.Account

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
  end
end
