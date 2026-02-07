defmodule Teiserver.Lobby.ScriptPasswordPersistenceTest do
  use Teiserver.ServerCase, async: false

  alias Teiserver.{Battle, Client, Lobby}
  alias Teiserver.Account.UserCacheLib
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  import Teiserver.TeiserverTestLib,
    only: [
      make_lobby: 0,
      new_user: 0,
      auth_setup: 1,
      auth_setup: 2,
      _send_raw: 2,
      _recv_raw: 1,
      _recv_until: 1,
      start_spring_server: 1
    ]

  describe "LobbyServer script_password storage" do
    test "stores script_password when user is added to battle" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "test_password_123")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user.id] == "test_password_123"
    end

    test "removes script_password when user leaves" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "removable_pw")
      :timer.sleep(100)
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "removable_pw"

      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(100)
      refute Map.has_key?(Battle.get_lobby_script_passwords(lobby_id), user.id)
    end

    test "stores distinct passwords for multiple users" do
      lobby_id = make_lobby()
      user1 = new_user()
      user2 = new_user()
      user3 = new_user()

      Lobby.add_user_to_battle(user1.id, lobby_id, "pw_alpha")
      Lobby.add_user_to_battle(user2.id, lobby_id, "pw_beta")
      Lobby.add_user_to_battle(user3.id, lobby_id, "pw_gamma")
      :timer.sleep(100)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user1.id] == "pw_alpha"
      assert passwords[user2.id] == "pw_beta"
      assert passwords[user3.id] == "pw_gamma"
      assert map_size(passwords) == 3
    end

    test "returns nil for non-existent lobby" do
      assert Battle.get_lobby_script_passwords(999_999_999) == nil
    end

    test "password is updated on rejoin" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id, "first_pw")
      :timer.sleep(100)
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "first_pw"

      Lobby.remove_user_from_battle(user.id, lobby_id)
      :timer.sleep(50)
      Lobby.add_user_to_battle(user.id, lobby_id, "second_pw")
      :timer.sleep(100)
      assert Battle.get_lobby_script_passwords(lobby_id)[user.id] == "second_pw"
    end

    test "add_user_to_battle/2 auto-generates a stored password" do
      lobby_id = make_lobby()
      user = new_user()

      Lobby.add_user_to_battle(user.id, lobby_id)
      :timer.sleep(100)

      password = Battle.get_lobby_script_passwords(lobby_id)[user.id]
      assert is_binary(password) and byte_size(password) > 0
    end

    test "starts empty for new lobby" do
      lobby_id = make_lobby()
      assert Battle.get_lobby_script_passwords(lobby_id) == %{}
    end
  end

  describe "Spring protocol integration: host sees script_password in JOINEDBATTLE" do
    setup :start_spring_server

    setup(context) do
      Teiserver.TeiserverTestLib.start_coordinator!()
      %{socket: socket, user: user} = auth_setup(context)
      UserCacheLib.update_user(%{user | roles: ["Bot" | user.roles]}, persist: false)
      {:ok, socket: socket, user: user}
    end

    defp open_battle(host_socket) do
      _send_raw(
        host_socket,
        "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tscript_pw_test\tgameTitle\tgameName\n"
      )

      reply = _recv_until(host_socket)
      [_, lobby_id] = Regex.run(~r/OPENBATTLE ([0-9]+)\n/, reply)
      int_parse(lobby_id)
    end

    test "host receives script_password in JOINEDBATTLE on player join",
         %{socket: host_socket} = context do
      lobby_id = open_battle(host_socket)

      user2 = new_user()
      %{socket: p_socket} = auth_setup(context, user2)
      _ = _recv_until(host_socket)

      _send_raw(p_socket, "JOINBATTLE #{lobby_id} empty my_script_pw\n")
      _ = _recv_raw(host_socket)
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user2.name}\n")
      _ = _recv_until(p_socket)

      reply = _recv_until(host_socket)
      assert reply =~ "JOINEDBATTLE #{lobby_id} #{user2.name} my_script_pw"
    end

    test "script_password persists in LobbyServer after player joins",
         %{socket: host_socket} = context do
      lobby_id = open_battle(host_socket)

      user2 = new_user()
      %{socket: p_socket} = auth_setup(context, user2)
      _ = _recv_until(host_socket)

      _send_raw(p_socket, "JOINBATTLE #{lobby_id} empty persist_pw\n")
      _ = _recv_raw(host_socket)
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user2.name}\n")
      _ = _recv_until(p_socket)
      _ = _recv_until(host_socket)

      passwords = Battle.get_lobby_script_passwords(lobby_id)
      assert passwords[user2.id] == "persist_pw"
    end

    test "new client login sees stored password (reconnect scenario)",
         %{socket: host_socket} = context do
      lobby_id = open_battle(host_socket)

      user2 = new_user()
      %{socket: p_socket} = auth_setup(context, user2)
      _ = _recv_until(host_socket)

      _send_raw(p_socket, "JOINBATTLE #{lobby_id} empty reconnect_pw\n")
      _ = _recv_raw(host_socket)
      _send_raw(host_socket, "JOINBATTLEACCEPT #{user2.name}\n")
      _ = _recv_until(p_socket)
      _ = _recv_until(host_socket)

      assert Battle.get_lobby_script_passwords(lobby_id)[user2.id] == "reconnect_pw"

      # New client logs in -- do_login_accepted enumerates lobbies.
      # Pre-fix this would send script_password: nil. Post-fix it looks up from LobbyServer.
      %{socket: _new_socket} = auth_setup(context)

      # Password must still be intact after the new login triggered enumeration
      assert Battle.get_lobby_script_passwords(lobby_id)[user2.id] == "reconnect_pw"
    end
  end

  describe "GenServer injection: host JOINEDBATTLE output includes script_password" do
    setup :start_spring_server

    setup(context) do
      Teiserver.TeiserverTestLib.start_coordinator!()
      %{socket: socket, user: user} = auth_setup(context)
      UserCacheLib.update_user(%{user | roles: ["Bot" | user.roles]}, persist: false)
      {:ok, socket: socket, user: user}
    end

    test "lobby host sees script_password when joined_lobby message is injected",
         %{socket: host_socket, user: host_user} = context do
      # Open battle so this socket becomes a lobby host
      _send_raw(
        host_socket,
        "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tinject_test\tgameTitle\tgameName\n"
      )

      reply = _recv_until(host_socket)
      [_, lobby_id_str] = Regex.run(~r/OPENBATTLE ([0-9]+)\n/, reply)
      lobby_id = int_parse(lobby_id_str)

      # Create a second user so the host knows about them
      %{user: u2} = auth_setup(context)
      _ = _recv_until(host_socket)

      # Get the host's TCP GenServer pid
      host_client = Client.get_client_by_id(host_user.id)
      tcp_pid = host_client.tcp_pid

      # Inject a joined_lobby message directly into the host's GenServer
      send(tcp_pid, %{
        channel: "teiserver_global_user_updates",
        event: :joined_lobby,
        client: Client.get_client_by_id(u2.id),
        lobby_id: lobby_id,
        script_password: "injected_pw"
      })

      reply = _recv_until(host_socket)
      assert reply =~ "JOINEDBATTLE #{lobby_id} #{u2.name} injected_pw"
    end

    test "non-host does not see script_password in JOINEDBATTLE",
         %{socket: host_socket} = context do
      _send_raw(
        host_socket,
        "OPENBATTLE 0 0 empty 322 16 gameHash 0 mapHash engineName\tengineVersion\tinject_test2\tgameTitle\tgameName\n"
      )

      reply = _recv_until(host_socket)
      [_, lobby_id_str] = Regex.run(~r/OPENBATTLE ([0-9]+)\n/, reply)
      lobby_id = int_parse(lobby_id_str)

      # Create observer (not the host) and a joining user
      %{socket: obs_socket, user: obs_user} = auth_setup(context)
      %{user: u3} = auth_setup(context)
      _ = _recv_until(obs_socket)

      obs_client = Client.get_client_by_id(obs_user.id)
      obs_pid = obs_client.tcp_pid

      # Inject into the observer's GenServer (not a host)
      send(obs_pid, %{
        channel: "teiserver_global_user_updates",
        event: :joined_lobby,
        client: Client.get_client_by_id(u3.id),
        lobby_id: lobby_id,
        script_password: "secret_pw"
      })

      reply = _recv_until(obs_socket)
      # Observer should see JOINEDBATTLE without the password
      assert reply =~ "JOINEDBATTLE #{lobby_id} #{u3.name}\n"
      refute reply =~ "secret_pw"
    end
  end
end
