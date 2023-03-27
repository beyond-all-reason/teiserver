defmodule Teiserver.Protocols.V1.TachyonSocialTest do
  use Central.ServerCase
  alias Teiserver.{Account, User, Client}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    %{socket: socket, user: user, pid: pid} = tachyon_auth_setup()

    %{user: friend1} = tachyon_auth_setup()
    %{user: friend2} = tachyon_auth_setup()
    %{user: pending_friend} = tachyon_auth_setup()
    %{user: ignored} = tachyon_auth_setup()
    %{user: nobody} = tachyon_auth_setup()

    # Now setup the friends and ignores
    User.create_friend_request(user.id, friend1.id)
    User.create_friend_request(user.id, friend2.id)

    User.accept_friend_request(user.id, friend1.id)
    User.accept_friend_request(user.id, friend2.id)

    User.create_friend_request(user.id, pending_friend.id)

    User.ignore_user(user.id, ignored.id)

    # Friend 2 now needs to log out
    Client.disconnect(friend2.id)

    {:ok,
     socket: socket,
     user: user,
     pid: pid,
     friend1: friend1,
     friend2: friend2,
     pending_friend: pending_friend,
     ignored: ignored,
     nobody: nobody}
  end

  test "friends", %{
    socket: socket,
    user: user,
    friend1: friend1,
    friend2: friend2
  } do
    User.remove_friend(friend1.id, user.id)
    User.remove_friend(friend2.id, user.id)

    _tachyon_recv_until(socket)

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids"})
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.list_friend_ids",
             "friend_id_list" => [],
             "request_id_list" => []
           }

    user = Account.get_user_by_id(user.id)
    assert user.friends == []
    assert user.friend_requests == []

    # We request for friend1, friend2 requests for us
    _tachyon_send(socket, %{"cmd" => "c.user.add_friend", "user_id" => friend1.id})
    resp = _tachyon_recv(socket)
    assert resp == :timeout

    # Ensure users are updated correctly
    user = Account.get_user_by_id(user.id)
    assert user.friends == []
    assert user.friend_requests == []

    friend1 = Account.get_user_by_id(friend1.id)
    assert friend1.friends == []
    assert friend1.friend_requests == [user.id]

    User.create_friend_request(friend2.id, user.id)

    # Ensure users are updated correctly
    user = Account.get_user_by_id(user.id)
    assert user.friends == []
    assert user.friend_requests == [friend2.id]

    # We should now get a message asking us to be friends
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.friend_request",
             "user_id" => friend2.id
           }

    # Check the data
    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids"})
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.list_friend_ids",
             "friend_id_list" => [],
             "request_id_list" => [friend2.id]
           }

    # Now reject that request
    _tachyon_send(socket, %{"cmd" => "c.user.reject_friend_request", "user_id" => friend2.id})
    resp = _tachyon_recv(socket)
    assert resp == :timeout

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids"})
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.list_friend_ids",
             "friend_id_list" => [],
             "request_id_list" => []
           }

    # Check friend1 has us in their list
    assert Account.get_user_by_id(friend1.id).friend_requests == [user.id]

    # Rescind it
    _tachyon_send(socket, %{"cmd" => "c.user.rescind_friend_request", "user_id" => friend1.id})
    resp = _tachyon_recv(socket)
    assert resp == :timeout

    assert Account.get_user_by_id(friend1.id).friend_requests == []

    # Accept a friend request that's not there
    _tachyon_send(socket, %{"cmd" => "c.user.accept_friend_request", "user_id" => friend2.id})
    resp = _tachyon_recv(socket)
    assert resp == :timeout

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids"})
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.list_friend_ids",
             "friend_id_list" => [],
             "request_id_list" => []
           }

    # Ensure everything is as we expect
    user = Account.get_user_by_id(user.id)
    assert user.friends == []
    assert user.friend_requests == []

    friend1 = Account.get_user_by_id(friend1.id)
    assert friend1.friends == []
    assert friend1.friend_requests == []

    friend2 = Account.get_user_by_id(friend2.id)
    assert friend2.friends == []
    assert friend2.friend_requests == []

    # Add a friend again
    _tachyon_send(socket, %{"cmd" => "c.user.add_friend", "user_id" => friend1.id})
    resp = _tachyon_recv(socket)
    assert resp == :timeout

    # Accept
    User.accept_friend_request(user.id, friend1.id)

    friend1 = Account.get_user_by_id(friend1.id)
    assert friend1.friends == [user.id]
    assert friend1.friend_requests == []

    user = Account.get_user_by_id(user.id)
    assert user.friends == [friend1.id]
    assert user.friend_requests == []

    # Accept it
    User.accept_friend_request(user.id, friend1.id)

    resp = _tachyon_recv(socket)
    assert resp == [%{"cmd" => "s.user.friend_added", "user_id" => friend1.id}]

    resp = _tachyon_recv(socket)
    assert resp == :timeout

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids"})
    [resp] = _tachyon_recv(socket)

    assert resp == %{
             "cmd" => "s.user.list_friend_ids",
             "friend_id_list" => [friend1.id],
             "request_id_list" => []
           }

    # Now add friend2 too
    User.create_friend_request(user.id, friend2.id)
    User.accept_friend_request(user.id, friend2.id)

    resp = _tachyon_recv(socket)
    assert resp == [%{"cmd" => "s.user.friend_added", "user_id" => friend2.id}]

    resp = _tachyon_recv(socket)
    assert resp == :timeout

    user = Account.get_user_by_id(user.id)
    assert user.friends == [friend2.id, friend1.id]
    assert user.friend_requests == []

    # Now try c.user.list_friend_users_and_clients
    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_users_and_clients"})
    [resp] = _tachyon_recv(socket)
    assert Map.keys(resp) |> Enum.sort() == ["client_list", "cmd", "user_list"]
    assert resp["cmd"] == "s.user.list_friend_users_and_clients"

    client_ids = resp["client_list"] |> Enum.map(fn c -> c["userid"] end) |> Enum.sort()
    assert client_ids == [friend1.id]

    user_ids = resp["user_list"] |> Enum.map(fn c -> c["id"] end) |> Enum.sort()
    assert user_ids == [friend1.id, friend2.id]
  end
end
