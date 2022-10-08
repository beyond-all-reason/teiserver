defmodule Teiserver.Protocols.V1.TachyonAuthTest do
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

  test "tachyon end to end", %{socket: socket, user: user, friend1: friend1, friend2: friend2, pid: pid} do
    initial_last_message = :sys.get_state(pid)
    assert initial_last_message != nil

    # Flush!
    _tachyon_recv_until(socket)

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

    # Now include clients
    _tachyon_send(socket, %{"cmd" => "c.user.list_users_from_ids", "id_list" => friend_list, "include_clients" => true})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.user.user_list"
    [client] = resp["clients"]
    assert client["sync"] == %{"engine" => 0, "game" => 0, "map" => 0}
    users_map = resp["users"]
      |> Map.new(fn u -> {u["id"], u} end)

    assert Enum.count(resp["users"]) == 2
    assert users_map[friend1.id]["name"] == friend1.name
    assert users_map[friend2.id]["name"] == friend2.name

    clients_map = resp["clients"]
      |> Map.new(fn u -> {u["userid"], u} end)

    # Only one of the users is logged in so only 1 client
    assert Enum.count(resp["clients"]) == 1
    assert clients_map[friend1.id]["ready"] == false
    assert clients_map[friend2.id] == nil

    # Lets get their client state
    _tachyon_send(socket, %{"cmd" => "c.client.list_clients_from_ids", "id_list" => friend_list})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.client.client_list"
    client_list = resp["clients"]

    assert Enum.count(client_list) == 1
    [f1_client] = client_list
    assert f1_client["userid"] == friend1.id

    # List lobbies
    # First we don't send a query, should error
    _tachyon_send(socket, %{"cmd" => "c.lobby.query"})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "error" => "no query supplied",
      "location" => "c.lobby.query",
      "result" => "error"
    }

    # Now we do an empty query, there are no lobbies so we expect an empty result
    _tachyon_send(socket, %{"cmd" => "c.lobby.query", "query" => %{}})
    [resp] = _tachyon_recv(socket)
    assert resp == %{
      "cmd" => "s.lobby.query",
      "lobbies" => [],
      "result" => "success"
    }

    # Lets get a lobby hosted
    {_lobby1, host1, _hsocket1} = create_lobby(%{name: "Test lobby 1"})
    {lobby2, _host2, hsocket2} = create_lobby(%{name: "Test lobby 2"})
    {_lobby_passworded, _host_passworded, _hsocketpassworded} = create_lobby(%{name: "Test lobby passworded", password: "password2"})
    {_lobby_locked, _host_locked, _hsocketlocked} = create_lobby(%{name: "Test lobby locked", locked: true})

    # We expect to get all 4 of them
    _tachyon_send(socket, %{"cmd" => "c.lobby.query", "query" => %{}})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.lobby.query"
    assert resp["result"] == "success"
    lobbies = resp["lobbies"]
      |> Map.new(fn l -> {l["lobby"]["name"], l["lobby"]} end)

    assert Enum.count(lobbies) == 4
    assert Map.has_key?(lobbies, "Test lobby 1")
    assert Map.has_key?(lobbies, "Test lobby 2")
    assert Map.has_key?(lobbies, "Test lobby passworded")
    assert Map.has_key?(lobbies, "Test lobby locked")

    assert lobbies["Test lobby 1"]["founder_id"] == host1.id
    assert lobbies["Test lobby 1"]["locked"] == false
    assert lobbies["Test lobby locked"]["locked"] == true

    # Now just the locked
    _tachyon_send(socket, %{"cmd" => "c.lobby.query", "query" => %{"locked" => true}})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.lobby.query"
    assert resp["result"] == "success"
    assert Enum.count(resp["lobbies"]) == 1

    # Now just the unlocked
    _tachyon_send(socket, %{"cmd" => "c.lobby.query", "query" => %{"locked" => false}})
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.lobby.query"
    assert resp["result"] == "success"
    assert Enum.count(resp["lobbies"]) == 3

    # We want to join one of them
    _tachyon_send(socket, %{"cmd" => "c.lobby.join", "lobby_id" => lobby2["id"]})
    [resp] = _tachyon_recv(socket)
    assert resp == %{"cmd" => "s.lobby.join", "result" => "waiting_for_host"}

    # Host will approve us
    _tachyon_send(hsocket2, %{cmd: "c.lobby_host.respond_to_join_request", userid: user.id, response: "approve"})

    # We should now get info saying we are in
    [resp] = _tachyon_recv(socket)
    assert resp["cmd"] == "s.lobby.joined"
    assert Map.has_key?(resp, "lobby")
    assert Map.has_key?(resp, "bots")
    assert Map.has_key?(resp, "member_list")

    # And the last message should have been updated by now
    new_last_message = :sys.get_state(pid)
    assert initial_last_message != new_last_message
  end


  defp create_lobby(params) do
    %{socket: socket, user: user} = tachyon_auth_setup()
    # Open the lobby
    lobby_data = Map.merge(%{
      cmd: "c.lobby.create",
      name: "EU 01 - 123",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "koom valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }, params)

    # Create the lobby
    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(socket, data)
    _tachyon_recv(socket)

    # Update the lobby
    data = %{cmd: "c.lobby.update", lobby: params}
    _tachyon_send(socket, data)
    [reply] = _tachyon_recv(socket)

    {reply["lobby"], user, socket}
  end
end
