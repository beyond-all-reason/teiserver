defmodule Teiserver.Account.FriendRequestLibTest do
  use Teiserver.DataCase, async: true
  alias Teiserver.Account.AccountTestLib
  alias Teiserver.Account.{FriendRequest, FriendRequestLib}

  defp friend_request_fixture(%{id: id}, to), do: friend_request_fixture(id, to)
  defp friend_request_fixture(from, %{id: id}), do: friend_request_fixture(from, id)

  defp friend_request_fixture(from, to) do
    %FriendRequest{}
    |> FriendRequest.changeset(%{from_user_id: from, to_user_id: to})
    |> Teiserver.Repo.insert!()
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
end
