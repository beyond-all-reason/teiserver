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
end
