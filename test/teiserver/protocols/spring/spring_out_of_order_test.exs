defmodule Teiserver.SpringOutOfOrderTest do
  @moduledoc false
  use Central.ServerCase, async: false
  alias Teiserver.Account
  alias Teiserver.Account.ClientLib

  import Teiserver.TeiserverTestLib,
    only: [
      auth_setup: 0,
      _recv_until: 1,
      tachyon_auth_setup: 0,
      _tachyon_send: 2,
      _tachyon_recv: 1
    ]

  defp make_lobby() do
    %{socket: hsocket, user: host} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    Teiserver.User.update_user(%{host | moderator: true})
    ClientLib.refresh_client(host.id)

    lobby_data = %{
      cmd: "c.lobby.create",
      name: "Coordinator #{:rand.uniform(999_999_999)}",
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
    }

    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(hsocket, data)
    [reply] = _tachyon_recv(hsocket)
    reply["lobby"]["id"]
  end

  defp get_known_users(pid) do
    :sys.get_state(pid)
    |> Map.get(:known_users)
  end

  defp wipe_known_users(pid) do
    set_known_users(pid, %{})
  end

  defp set_known_users(pid, new_known) do
    send(pid, {:put, :known_users, new_known})
  end

  defp get_known_battles(pid) do
    :sys.get_state(pid)
    |> Map.get(:known_battles)
  end

  defp wipe_known_battles(pid) do
    set_known_battles(pid, %{})
  end

  defp set_known_battles(pid, new_known) do
    send(pid, {:put, :known_battles, new_known})
  end

  defp recv_until(socket) do
    _recv_until(socket)
      |> String.split("\n")
      |> Enum.reject(fn
        "" -> true
        _ -> false
      end)
  end

  setup do
    %{socket: socket, user: user} = auth_setup()
    {:ok, socket: socket, user: user}
  end

  # Still to do
  # handle_info({:action, {:ring, userid}}, state)
  # handle_info({:user_logged_in, userid}, state)
  # handle_info({:user_logged_out, userid, username}, state)
  # handle_info({:updated_client, new_client, reason}, state)
  # handle_info({:spring_add_user_from_login, client}, state)
  # handle_info({:direct_message, from, msg}, state)
  # handle_info({:new_message, from, room_name, msg}, state)
  # handle_info({:new_message_ex, from, room_name, msg}, state)
  # handle_info({:add_user_to_room, userid, room_name}, state)
  # handle_info({:remove_user_from_room, userid, room_name}, state)
  # handle_info({:request_user_join_lobby, userid}, state)
  # handle_info({:kick_user_from_battle, userid, lobby_id}, state)

  @doc """
  The issue we are seeing is in some situations the tcp server is not correctly inserting new instructions into the system. This test aims to be an exhaustive investigation
  into which call(s) are the issue
  """
  test "add_user_to_battle", %{socket: socket, user: user} do
    client = Account.get_client_by_id(user.id)
    pid = client.tcp_pid

    lobby1_id = make_lobby()

    %{user: user1} = auth_setup()

    # Clear everything from making the lobbies
    recv_until(socket)
    wipe_known_users(pid)

    r = recv_until(socket)
    assert r == []
    assert get_known_users(pid) == %{}

    # Add user to battle
    # Case 1, we are the user
    send(pid, {:add_user_to_battle, user.id, lobby1_id, "password"})

    r = recv_until(socket)
    assert r == []

    assert get_known_users(pid) == %{
      user.id => %{lobby_id: lobby1_id}
    }

    # Case 2, we do not know about the user
    wipe_known_users(pid)

    send(pid, {:add_user_to_battle, user1.id, lobby1_id, "password"})

    r = recv_until(socket)
    assert r == [
      "ADDUSER #{user1.name} ?? #{user1.id} LuaLobby Chobby",
      "CLIENTSTATUS #{user1.name} 0",
      "JOINEDBATTLE #{lobby1_id} #{user1.name}"
    ]

    assert get_known_users(pid) == %{
      user1.id => %{lobby_id: lobby1_id}
    }

    # Case 3, we know the user, they are not in a lobby
    set_known_users(pid, %{user1.id => %{lobby_id: nil}})

    send(pid, {:add_user_to_battle, user1.id, lobby1_id, "password"})

    r = recv_until(socket)
    assert r == [
      "JOINEDBATTLE #{lobby1_id} #{user1.name}"
    ]

    assert get_known_users(pid) == %{
      user1.id => %{lobby_id: lobby1_id}
    }

    # Case 4, we know the user, they are in a different lobby
    set_known_users(pid, %{user1.id => %{lobby_id: lobby1_id + 1}})

    send(pid, {:add_user_to_battle, user1.id, lobby1_id, "password"})

    r = recv_until(socket)
    assert r == [
      "JOINEDBATTLE #{lobby1_id} #{user1.name}"
    ]

    assert get_known_users(pid) == %{
      user1.id => %{lobby_id: lobby1_id}
    }
  end

  test "remove_user_from_battle", %{socket: socket, user: user} do
    client = Account.get_client_by_id(user.id)
    pid = client.tcp_pid

    lobby1_id = make_lobby()

    %{user: user1} = auth_setup()

    # Clear everything from making the lobbies
    recv_until(socket)

    # Case 1 - We don't know about the battle? Ignore it (but open the battle)
    wipe_known_users(pid)
    set_known_battles(pid, [])

    send(pid, {:remove_user_from_battle, user1.id, lobby1_id})

    r = recv_until(socket)
    assert Enum.count(r) == 1
    assert r |> hd |> String.split(" ") |> hd == "BATTLEOPENED"

    assert get_known_users(pid) == %{}

    # Case 2 - We don't even know who they are? Leave it too
    set_known_battles(pid, [lobby1_id])
    wipe_known_users(pid)

    send(pid, {:remove_user_from_battle, user1.id, lobby1_id})

    r = recv_until(socket)
    assert r == []

    assert get_known_users(pid) == %{}

    # Case 3 - We know them but not that they are in the lobby?
    set_known_users(pid, %{user1.id => %{lobby_id: nil}})

    send(pid, {:remove_user_from_battle, user1.id, lobby1_id})

    r = recv_until(socket)
    assert r == []

    assert get_known_users(pid) == %{user1.id => %{lobby_id: nil}}

    # Case 4 - We don't care which battle we thought they are in, they're no longer in it
    set_known_battles(pid, [lobby1_id])
    set_known_users(pid, %{user1.id => %{lobby_id: lobby1_id + 1}})

    send(pid, {:remove_user_from_battle, user1.id, lobby1_id})

    r = recv_until(socket)
    assert r == [
      "LEFTBATTLE #{lobby1_id + 1} #{user1.name}"
    ]

    assert get_known_users(pid) == %{
      user1.id => %{lobby_id: nil}
    }
  end

  test "CLIENTSTATUS", %{socket: socket, user: user} do
    client = Account.get_client_by_id(user.id)
    pid = client.tcp_pid

    recv_until(socket)

    client = %{
      userid: user.id + 1000,
      rank: 0,
      in_game: false,
      away: false,
      moderator: false,
      bot: false,
      name: "FakeMcFakeson",
      country: "??",
      lobby_client: "client_app"
    }

    send(pid, {:updated_client, client, :client_updated_status})

    r = recv_until(socket)
    assert r == [
      "ADDUSER FakeMcFakeson ?? #{user.id + 1000} client_app",
      "CLIENTSTATUS FakeMcFakeson 0"
    ]
  end
end
