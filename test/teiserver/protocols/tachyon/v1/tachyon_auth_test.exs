defmodule Teiserver.Protocols.V1.TachyonAuthTest do
  use Central.ServerCase
  alias Teiserver.{User, Client}
  alias Teiserver.Battle.Lobby

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

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

    # User.accept_friend_request(friend1.id, user.id)
    # User.accept_friend_request(friend2.id, user.id)

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

      nobody: nobody
    }
  end

  test "tachyon end to end", %{socket: socket, user: user, pid: pid, friend1: friend1, friend2: friend2} do
    # We are already logged in, lets start by getting a list of our friends!

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids", "filter" => ""})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.user.list_friend_ids"
    friend_list = resp["friend_id_list"]

    assert Enum.member?(friend_list, friend1.id)
    assert Enum.member?(friend_list, friend2.id)

    # User details
    _tachyon_send(socket, %{"cmd" => "c.user.list_users_from_ids", "id_list" => friend_list})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.user.user_list"
    users_map = resp["users"]
      |> Map.new(fn u -> {u["id"], u} end)

    assert Enum.count(resp["users"]) == 2
    assert users_map[friend1.id]["name"] == friend1.name
    assert users_map[friend2.id]["name"] == friend2.name

    # Lets get their client state
    _tachyon_send(socket, %{"cmd" => "c.client.list_clients", "id_list" => friend_list})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.client.client_list"
    client_list = resp["clients"]

    assert Enum.count(client_list) == 1
    [f1_client] = client_list
    assert f1_client["userid"] == friend1.id
  end
end
