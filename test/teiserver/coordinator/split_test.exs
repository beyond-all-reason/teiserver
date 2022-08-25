defmodule Teiserver.Coordinator.SplitTest do
  use Central.ServerCase, async: false
  alias Teiserver.Battle.Lobby
  alias Teiserver.Account.ClientLib
  alias Teiserver.Common.PubsubListener
  alias Teiserver.{User, Client, Coordinator}
  alias Teiserver.Coordinator.CoordinatorLib

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: hsocket_empty} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    User.update_user(%{host | moderator: true})
    User.update_user(%{player | moderator: true})
    ClientLib.refresh_client(host.id)
    ClientLib.refresh_client(player.id)

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
    lobby_id = reply["lobby"]["id"]

    listener = PubsubListener.new_listener(["teiserver_lobby_chat:#{lobby_id}"])

    # Create an empty battle for them
    lobby_data = %{
      cmd: "c.lobby.create",
      name: "Empty battle - #{:rand.uniform(999_999_999)}",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "empty valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "105.1.2.3",
      settings: %{
        max_players: 12
      }
    }
    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(hsocket_empty, data)
    [reply] = _tachyon_recv(hsocket_empty)
    empty_lobby_id = reply["lobby"]["id"]

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id, "script_password")
    player_client = Client.get_client_by_id(player.id)
    Client.update(%{player_client |
      player: true
    }, :client_updated_battlestatus)

    # Add user message
    _tachyon_recv(hsocket)

    # Battlestatus message
    _tachyon_recv(hsocket)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id, listener: listener, empty_lobby_id: empty_lobby_id}
  end


  test "basic split test", %{host: _host, player: player1, psocket: psocket1, lobby_id: lobby_id, listener: listener, empty_lobby_id: empty_lobby_id} do
    %{user: player2, socket: psocket2} = tachyon_auth_setup()
    %{user: player3, socket: psocket3} = tachyon_auth_setup()
    %{user: player4, socket: psocket4} = tachyon_auth_setup()
    %{user: player5, socket: psocket5} = tachyon_auth_setup()
    %{user: player6, socket: psocket6} = tachyon_auth_setup()

    # Add players to the lobby
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player3.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player4.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player5.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player6.id, lobby_id, "script_password")

    # Normally the player joins through the standard means but we're doing a test so it's a bit janky atm
    send(Client.get_client_by_id(player1.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player2.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player3.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player4.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player5.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player6.id).tcp_pid, {:put, :lobby_id, lobby_id})

    data = %{cmd: "c.lobby.message", message: "$splitlobby"}
    _tachyon_send(psocket1, data)

    # Check what got sent
    messages = PubsubListener.get(listener)
    assert messages == [{:lobby_chat, :say, lobby_id, player1.id, "$splitlobby"}]
    # assert messages == [
    #   {:lobby_chat, :announce, lobby_id, Coordinator.get_coordinator_userid(), "#{player1.name} is moving to a new lobby, to follow them say $y. If you want to follow someone else then say $follow <name> and you will follow that user. The split will take place in 30 seconds, you can change your mind at any time. Say $n to cancel your decision and stay here."},
    #   {:lobby_chat, :say, lobby_id, player1.id, "$splitlobby"},
    # ]

    # Check state
    split = Coordinator.call_consul(lobby_id, {:get, :split})
    assert split.first_splitter_id == player1.id
    assert split.splitters == %{}

    # Now they can say what they want to do!
    # 1 will say yes then no, they are the splitter so should have no impact
    # 2 will say yes
    # 3 will say yes then change their mind and say no
    # 4 will follow 2
    # 5 will follow 4 (and thus follow 2)
    # 6 will follow 1 (which should be translated to a yes)
    # End result should be 1, 2, 4, 5 move to a new lobby
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "$y"})
    _tachyon_send(psocket2, %{cmd: "c.lobby.message", message: "$y"})
    _tachyon_send(psocket3, %{cmd: "c.lobby.message", message: "$y"})
    _tachyon_send(psocket4, %{cmd: "c.lobby.message", message: "$follow #{player2.name}"})
    _tachyon_send(psocket5, %{cmd: "c.lobby.message", message: "$follow #{player4.name}"})
    _tachyon_send(psocket6, %{cmd: "c.lobby.message", message: "$follow #{player1.name}"})
    :timer.sleep(200)

    # Check state
    split = Coordinator.call_consul(lobby_id, {:get, :split})
    assert split.first_splitter_id == player1.id
    assert split.splitters == %{
      player1.id => true,
      player2.id => true,
      player3.id => true,
      player4.id => player2.id,
      player5.id => player4.id,
      player6.id => true
    }

    # Now update choices
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "$n"})
    _tachyon_send(psocket3, %{cmd: "c.lobby.message", message: "$n"})

    split = Coordinator.call_consul(lobby_id, {:get, :split})
    assert split.first_splitter_id == player1.id
    assert split.splitters == %{
      player2.id => true,
      player4.id => player2.id,
      player5.id => player4.id,
      player6.id => true
    }

    # Time to resolve
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "$dosplit"})
    :timer.sleep(200)

    assert Client.get_client_by_id(player1.id).lobby_id == empty_lobby_id
    assert Client.get_client_by_id(player2.id).lobby_id == empty_lobby_id
    assert Client.get_client_by_id(player3.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player4.id).lobby_id == empty_lobby_id
    assert Client.get_client_by_id(player5.id).lobby_id == empty_lobby_id
    assert Client.get_client_by_id(player6.id).lobby_id == empty_lobby_id
  end

  test "test split with different engine version", %{host: _host, player: player1, psocket: psocket1, lobby_id: lobby_id, listener: listener, empty_lobby_id: empty_lobby_id} do
    %{user: player2, socket: psocket2} = tachyon_auth_setup()
    %{user: player3, socket: psocket3} = tachyon_auth_setup()
    %{user: player4, socket: psocket4} = tachyon_auth_setup()
    %{user: player5, socket: psocket5} = tachyon_auth_setup()
    %{user: player6, socket: psocket6} = tachyon_auth_setup()

    # Add players to the lobby
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player3.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player4.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player5.id, lobby_id, "script_password")
    Lobby.add_user_to_battle(player6.id, lobby_id, "script_password")

    # Normally the player joins through the standard means but we're doing a test so it's a bit janky atm
    send(Client.get_client_by_id(player1.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player2.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player3.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player4.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player5.id).tcp_pid, {:put, :lobby_id, lobby_id})
    send(Client.get_client_by_id(player6.id).tcp_pid, {:put, :lobby_id, lobby_id})

    # Remove empty lobby with matching engine version
    Lobby.close_lobby(empty_lobby_id)

    # Add an empty lobby but with a different engine version
    lobby_data = %{
      cmd: "c.lobby.create",
      name: "Empty battle - #{:rand.uniform(999_999_999)}",
      nattype: "none",
      port: 1234,
      game_hash: "string_of_characters",
      map_hash: "string_of_characters",
      map_name: "empty valley",
      game_name: "BAR",
      engine_name: "spring-105",
      engine_version: "lex.1.2.3",
      settings: %{
        max_players: 12
      }
    }
    %{socket: hsocket_empty} = tachyon_auth_setup()
    data = %{cmd: "c.lobby.create", lobby: lobby_data}
    _tachyon_send(hsocket_empty, data)
    [reply] = _tachyon_recv(hsocket_empty)
    empty_lobby_id = reply["lobby"]["id"]

    data = %{cmd: "c.lobby.message", message: "$splitlobby"}
    _tachyon_send(psocket1, data)

    # Check what got sent
    messages = PubsubListener.get(listener)
    assert messages == [{:lobby_chat, :say, lobby_id, player1.id, "$splitlobby"}]

    # Check state
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "$y"})
    _tachyon_send(psocket2, %{cmd: "c.lobby.message", message: "$y"})
    _tachyon_send(psocket3, %{cmd: "c.lobby.message", message: "$y"})
    :timer.sleep(200)

    # Time to resolve
    _tachyon_send(psocket1, %{cmd: "c.lobby.message", message: "$dosplit"})
    :timer.sleep(200)

    # Split should fail because there are no empty lobbies with the same engine version as the starting one
    assert Client.get_client_by_id(player1.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player2.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player3.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player4.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player5.id).lobby_id == lobby_id
    assert Client.get_client_by_id(player6.id).lobby_id == lobby_id
  end

  test "test split resolving" do
    # Basic test
    result = CoordinatorLib.resolve_split(%{
      1 => true,
      2 => true,
    })
    assert result == %{
      1 => true,
      2 => true,
    }

    # Add a nil entry
    result = CoordinatorLib.resolve_split(%{
      1 => true,
      2 => true,
      3 => nil,
    })
    assert result == %{
      1 => true,
      2 => true,
    }

    # Swap it for a false, just to see
    result = CoordinatorLib.resolve_split(%{
      1 => true,
      2 => true,
      3 => false,
    })
    assert result == %{
      1 => true,
      2 => true,
    }

    # Add a follow
    result = CoordinatorLib.resolve_split(%{
      1 => true,
      2 => true,
      3 => nil,
      4 => 1,
    })
    assert result == %{
      1 => true,
      2 => true,
      4 => true,
    }

    # Add a follow of a follow and a negative follow
    result = CoordinatorLib.resolve_split(%{
      1 => true,
      2 => true,
      3 => nil,
      4 => 1,
      5 => 4,
      6 => 3,
    })
    assert result == %{
      1 => true,
      2 => true,
      4 => true,
      5 => true,
    }

    # Endless loop
    result = CoordinatorLib.resolve_split(%{
      1 => 2,
      2 => 3,
      3 => 4,
      4 => 1,
    })
    assert result == %{}

    # Endless loop with something true
    result = CoordinatorLib.resolve_split(%{
      1 => 2,
      2 => 3,
      3 => 4,
      4 => 1,
      5 => true
    })
    assert result == %{
      5 => true,
    }
  end
end
