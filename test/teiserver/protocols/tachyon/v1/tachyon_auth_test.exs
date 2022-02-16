defmodule Teiserver.Protocols.V1.TachyonAuthTest do
  use Central.ServerCase
  alias Teiserver.{User}
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

    User.accept_friend_request(friend1.id, user.id)
    User.create_friend_request(friend2.id, user.id)

    User.create_friend_request(user.id, pending_friend.id)

    User.ignore_user(user.id, ignored.id)

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

  test "tachyon end to end", %{socket: socket, user: user, pid: pid} do
    # We are already logged in, lets start by getting a list of our friends!

    _tachyon_send(socket, %{"cmd" => "c.user.list_friend_ids", "filter" => ""})
    friend_list = []

    _tachyon_send(socket, %{"cmd" => "c.client.list_clients", "id_list" => friend_list})


    # Now for matches
    _tachyon_send(socket, %{"cmd" => "c.lobby.list_lobbies"})
  end
end
