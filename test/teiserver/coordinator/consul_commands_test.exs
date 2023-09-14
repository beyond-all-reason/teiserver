defmodule Teiserver.Coordinator.ConsulCommandsTest do
  use Central.ServerCase, async: false
  alias Teiserver.Account.ClientLib
  alias Teiserver.Common.PubsubListener
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.{Account, Battle, User, Client, Coordinator, Lobby}
  alias Teiserver.Coordinator.ConsulServer

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1, _tachyon_recv_until: 1]

  setup do
    Coordinator.start_coordinator()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()

    # User needs to be a moderator (at this time) to start/stop Coordinator mode
    User.update_user(%{host | moderator: true})
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
    lobby_id = reply["lobby"]["id"]

    listener = PubsubListener.new_listener(["teiserver_lobby_chat:#{lobby_id}"])

    # Player needs to be added to the battle
    Lobby.add_user_to_battle(player.id, lobby_id)
    _tachyon_send(psocket, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})
    _tachyon_recv_until(psocket)

    # Add user message
    _tachyon_recv_until(hsocket)

    # Battlestatus message
    _tachyon_recv_until(hsocket)

    {:ok,
     hsocket: hsocket,
     psocket: psocket,
     host: host,
     player: player,
     lobby_id: lobby_id,
     listener: listener}
  end

  defp make_rating(userid, rating_type_id, rating_value) do
    {:ok, _} =
      Account.create_rating(%{
        user_id: userid,
        rating_type_id: rating_type_id,
        rating_value: rating_value,
        skill: rating_value,
        uncertainty: 0,
        leaderboard_rating: rating_value,
        last_updated: Timex.now()
      })
  end

  test "non existent command", %{hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", message: "$creativecommandname"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)
    assert reply["message"] == "No command of name 'creativecommandname'"
  end

  test "non allowed command", %{lobby_id: lobby_id, psocket: psocket, player: player} do
    Lobby.force_add_user_to_lobby(player.id, lobby_id)
    player_client = Account.get_client_by_id(player.id)

    Client.update(
      %{player_client | player: false, ready: false},
      :client_updated_battlestatus
    )

    _tachyon_recv(psocket)

    data = %{cmd: "c.lobby.message", message: "$specunready"}
    _tachyon_send(psocket, data)

    [reply] = _tachyon_recv(psocket)
    assert reply["message"] == "You are not allowed to use the 'specunready' command (host only)"

    data = %{cmd: "c.lobby.message", message: "$meme"}
    _tachyon_send(psocket, data)

    [reply] = _tachyon_recv(psocket)
    assert reply["message"] == "You are not allowed to use the 'meme' command (boss only)"
  end

  test "specunready", %{lobby_id: lobby_id, player: player1, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Account.get_client_by_id(player2.id)

    Client.update(
      %{player_client | player: false, ready: false},
      :client_updated_battlestatus
    )

    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", message: "$specunready"}
    _tachyon_send(hsocket, data)

    # Now we check they are ready or they're a spectator
    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) end)
      |> Enum.map(fn c -> c.player == false or c.ready == true end)

    assert readies == [true, true]

    # Unready both again
    player_client = Account.get_client_by_id(player1.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    player_client = Account.get_client_by_id(player2.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]
  end

  test "makeready", %{lobby_id: lobby_id, player: player1, hsocket: hsocket} do
    %{user: player2} = tachyon_auth_setup()

    # Add player2 to the battle but as a spectator
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client = Account.get_client_by_id(player2.id)

    Client.update(
      %{player_client | player: true, ready: false},
      :client_updated_battlestatus
    )

    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    data = %{cmd: "c.lobby.message", message: "$makeready"}
    _tachyon_send(hsocket, data)

    # Now we get the ready statuses
    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [true, true]

    # Unready both again
    player_client = Account.get_client_by_id(player1.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    player_client = Account.get_client_by_id(player2.id)
    Client.update(%{player_client | ready: false}, :client_updated_battlestatus)

    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, false]

    # Now make one of them ready
    data = %{cmd: "c.lobby.message", message: "$makeready ##{player1.id}"}
    _tachyon_send(hsocket, data)

    readies =
      Battle.get_lobby(lobby_id)
      |> Map.get(:players)
      |> Enum.map(fn userid -> Account.get_client_by_id(userid) |> Map.get(:ready) end)

    assert readies == [false, true]
  end

  test "specafk", %{player: player1, psocket: psocket1, hsocket: hsocket, lobby_id: lobby_id} do
    %{socket: psocket2, user: player2} = tachyon_auth_setup()
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    player_client1 = Account.get_client_by_id(player1.id)

    Client.update(
      %{player_client1 | player: true},
      :client_updated_battlestatus
    )

    player_client2 = Account.get_client_by_id(player2.id)

    Client.update(
      %{player_client2 | player: true},
      :client_updated_battlestatus
    )

    player_client1 = Account.get_client_by_id(player1.id)
    player_client2 = Account.get_client_by_id(player2.id)
    assert player_client1.player == true
    assert player_client2.player == true

    :timer.sleep(1000)

    _ = _tachyon_recv_until(hsocket)
    _ = _tachyon_recv_until(psocket1)
    _ = _tachyon_recv_until(psocket2)

    # Say the command
    data = %{cmd: "c.lobby.message", message: "$specafk"}
    _tachyon_send(hsocket, data)

    # Status update for the first, can happen in either order
    [reply1] = _tachyon_recv(hsocket)
    assert reply1["cmd"] == "s.lobby.updated_client_battlestatus"
    assert reply1["client"]["userid"] == player2.id or reply1["client"]["userid"] == player1.id

    # And now the other
    [reply2] = _tachyon_recv(hsocket)
    assert reply2["cmd"] == "s.lobby.updated_client_battlestatus"
    assert reply2["client"]["userid"] == player2.id or reply2["client"]["userid"] == player1.id

    # Ensure it wasn't the same user twice
    assert reply1["client"]["userid"] != reply2["client"]["userid"]

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["message"] == "$specafk"

    # Both players should get a message from the coordinator
    [reply] = _tachyon_recv(psocket1)
    assert reply["cmd"] == "s.communication.received_direct_message"

    assert reply["message"] ==
             "The lobby you are in is conducting an AFK check, please respond with 'hello' here to show you are not afk or just type something into the lobby chat."

    [reply] = _tachyon_recv(psocket2)
    assert reply["cmd"] == "s.communication.received_direct_message"

    assert reply["message"] ==
             "The lobby you are in is conducting an AFK check, please respond with 'hello' here to show you are not afk or just type something into the lobby chat."

    # Check consul state
    pid = Coordinator.get_consul_pid(lobby_id)

    state = :sys.get_state(pid)
    assert state.afk_check_list == [player2.id, player1.id]
    assert state.afk_check_at != nil

    send(pid, :tick)

    state = :sys.get_state(pid)
    assert state.afk_check_list == [player2.id, player1.id]
    assert state.afk_check_at != nil

    # Send the wrong message
    data = %{
      cmd: "c.communication.send_direct_message",
      message: "this is the wrong message",
      recipient_id: Coordinator.get_coordinator_userid()
    }

    _tachyon_send(psocket1, data)

    send(pid, :tick)
    state = :sys.get_state(pid)
    assert state.afk_check_list == [player2.id, player1.id]
    assert state.afk_check_at != nil

    # Now send the correct message
    data = %{
      cmd: "c.communication.send_direct_message",
      message: "hello",
      recipient_id: Coordinator.get_coordinator_userid()
    }

    _tachyon_send(psocket1, data)

    send(pid, :tick)
    state = :sys.get_state(pid)
    assert state.afk_check_list == [player2.id]
    assert state.afk_check_at != nil

    _ = _tachyon_recv_until(hsocket)

    # Now we say time has elapsed
    send(pid, {:put, :afk_check_at, 1})
    send(pid, :tick)

    state = :sys.get_state(pid)
    assert state.afk_check_list == []
    assert state.afk_check_at == nil

    player_client1 = Account.get_client_by_id(player1.id)
    player_client2 = Account.get_client_by_id(player2.id)
    assert player_client1.player == true
    assert player_client2.player == false

    # What has happened now?
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.updated_client_battlestatus"
    assert reply["client"]["userid"] == player2.id
    assert reply["client"]["player"] == false

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["message"] == "AFK-check is now complete, 1 player(s) were found to be afk"
  end

  test "pull user", %{lobby_id: lobby_id, hsocket: hsocket, host: _host} do
    %{user: player2, socket: psocket} = tachyon_auth_setup()

    data = %{cmd: "c.lobby.message", message: "$pull ##{player2.id}"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(psocket)
    assert reply["cmd"] == "s.lobby.joined"
    assert reply["lobby"]["id"] == lobby_id
  end

  test "pull users", %{lobby_id: lobby_id, hsocket: hsocket} do
    %{user: player2, socket: socket2} = tachyon_auth_setup()
    %{user: player3, socket: socket3} = tachyon_auth_setup()

    data = %{cmd: "c.lobby.message", message: "$pull ##{player2.id} ##{player3.id}"}
    _tachyon_send(hsocket, data)

    [reply2] = _tachyon_recv(socket2)
    assert reply2["cmd"] == "s.lobby.joined"
    assert reply2["lobby"]["id"] == lobby_id

    [reply3] = _tachyon_recv(socket3)
    assert reply3["cmd"] == "s.lobby.joined"
    assert reply3["lobby"]["id"] == lobby_id
  end

  # TODO: settag

  test "explain and bstatus", %{lobby_id: lobby_id, hsocket: hsocket, host: host, player: player} do
    # Set fuzzer to 0 or we get inconsistent values and our test breaks
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$set fuzz_multiplier 0"})

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.say",
             "lobby_id" => lobby_id,
             "message" => "$set fuzz_multiplier 0",
             "sender_id" => host.id
           }

    rating_type_id = MatchRatingLib.rating_type_name_lookup()["Duel"]
    make_rating(player.id, rating_type_id, 20)

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$%explain"})

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.communication.received_direct_message",
             "message" =>
               [
                 "---------------------------",
                 "No balance has been created for this room",
                 "---------------------------"
               ]
               |> Enum.join("\n"),
             "sender_id" => Coordinator.get_coordinator_userid()
           }

    balance_result =
      Coordinator.call_balancer(lobby_id, {
        :make_balance,
        2,
        [allow_groups: true]
      })

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$%explain"})

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.communication.received_direct_message",
             "message" =>
               [
                 "---------------------------",
                 "Balance logs, mode: solo",
                 "Tried grouped mode, got a deviation of 100 and reverted to solo mode",
                 "Picked #{player.name} for team 1, adding 16.67 points for new total of 16.67",
                 "Deviation of: 100",
                 "Team 1 - sum: 16.7, mean: 16.7, stdev: 0.0",
                 "Team 2 - sum: 0.0, mean: 0.0, stdev: 0.0",
                 "Time taken: #{balance_result.time_taken}us",
                 "---------------------------"
               ]
               |> Enum.join("\n"),
             "sender_id" => Coordinator.get_coordinator_userid()
           }

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$%bstatus"})

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.communication.received_direct_message",
             "message" =>
               [
                 "--------------------------- Balancer status ---------------------------",
                 "algorithm: loser_picks",
                 "fuzz_multiplier: 0",
                 "hashes: 1",
                 "max_deviation: 10",
                 "mean_diff_max: 5",
                 "rating_lower_boundary: 3",
                 "rating_upper_boundary: 5",
                 "shuffle_first_pick: true",
                 "stddev_diff_max: 3"
               ]
               |> Enum.join("\n"),
             "sender_id" => Coordinator.get_coordinator_userid()
           }
  end

  test "ratingtoplay", %{lobby_id: lobby_id, hsocket: hsocket} do
    # Minimum
    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 0

    data = %{cmd: "c.lobby.message", message: "$minplaylevel 3"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 3

    data = %{cmd: "c.lobby.message", message: "$minplaylevel Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 3

    # Maximum
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 1000

    data = %{cmd: "c.lobby.message", message: "$maxplaylevel 13"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 13

    data = %{cmd: "c.lobby.message", message: "$maxplaylevel Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 13

    # Now try to set each the other side of the other
    data = %{cmd: "c.lobby.message", message: "$maxplaylevel 1"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 4

    data = %{cmd: "c.lobby.message", message: "$maxplaylevel 16"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 16

    data = %{cmd: "c.lobby.message", message: "$minplaylevel 20"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 15

    data = %{cmd: "c.lobby.message", message: "$setplaylevels 7 9"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 7
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 9

    data = %{cmd: "c.lobby.message", message: "$setplaylevels 50 33"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 33
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 50

    data = %{cmd: "c.lobby.message", message: "$resetplaylevels"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rating_to_play}) == 0
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rating_to_play}) == 1000
  end

  test "ranktoplay", %{lobby_id: lobby_id, hsocket: hsocket} do
    # Minimum
    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 0

    data = %{cmd: "c.lobby.message", message: "$minranklevel 3"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 3

    data = %{cmd: "c.lobby.message", message: "$minranklevel Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 3

    # Maximum
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 1000

    data = %{cmd: "c.lobby.message", message: "$maxranklevel 13"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 13

    data = %{cmd: "c.lobby.message", message: "$maxranklevel Xy"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 13

    # Now try to set each the other side of the other
    data = %{cmd: "c.lobby.message", message: "$maxranklevel 1"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 4

    data = %{cmd: "c.lobby.message", message: "$maxranklevel 16"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 16

    data = %{cmd: "c.lobby.message", message: "$minranklevel 20"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 15

    data = %{cmd: "c.lobby.message", message: "$setranklevels 7 9"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 7
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 9

    data = %{cmd: "c.lobby.message", message: "$setranklevels 50 33"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 33
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 50

    data = %{cmd: "c.lobby.message", message: "$resetranklevels"}
    _tachyon_send(hsocket, data)
    :timer.sleep(500)

    assert Coordinator.call_consul(lobby_id, {:get, :minimum_rank_to_play}) == 0
    assert Coordinator.call_consul(lobby_id, {:get, :maximum_rank_to_play}) == 1000
  end

  test "timeout", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Account.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$timeout #{player.name} Because I said so"}
    _tachyon_send(hsocket, data)

    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state (we added this after bans, don't want to get them confused)
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{}

    timeouts = Coordinator.call_consul(lobby_id, {:get, :timeouts})
    assert timeouts == %{player.id => %{by: host.id, level: :banned, reason: "Because I said so"}}

    assert Coordinator.call_consul(lobby_id, {:request_user_join_lobby, player.id}) ==
             {false, "Because I said so"}

    # Check timeout state
    timeouts = Coordinator.call_consul(lobby_id, {:get, :timeouts})
    assert timeouts == %{player.id => %{by: host.id, level: :banned, reason: "Because I said so"}}

    # Now we say the match ended
    Coordinator.cast_consul(lobby_id, :match_stop)

    assert Coordinator.call_consul(lobby_id, {:request_user_join_lobby, player.id}) == {true, nil}

    timeouts = Coordinator.call_consul(lobby_id, {:get, :timeouts})
    assert timeouts == %{}
  end

  test "kick by name", %{player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Account.get_client_by_id(player.id)
    assert player_client.player == true

    data = %{cmd: "c.lobby.message", message: "$lobbykick #{player.name}"}
    _tachyon_send(hsocket, data)

    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{}
  end

  test "ban by name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id

    data = %{cmd: "c.lobby.message", message: "$lobbyban #{player.name} Because I said so"}
    _tachyon_send(hsocket, data)

    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{player.id => %{by: host.id, level: :banned, reason: "Because I said so"}}
  end

  test "ban by partial name", %{host: host, player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id

    data = %{cmd: "c.lobby.message", message: "$lobbyban #{player.name |> String.slice(0, 5)}"}
    _tachyon_send(hsocket, data)

    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})
    assert bans == %{player.id => %{by: host.id, level: :banned, reason: "Banned"}}
  end

  test "error with no name", %{player: player, hsocket: hsocket, lobby_id: lobby_id} do
    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id

    data = %{cmd: "c.lobby.message", message: "$kick noname"}
    _tachyon_send(hsocket, data)

    # They should not be kicked, we expect no other errors at this stage
    player_client = Account.get_client_by_id(player.id)
    assert player_client.lobby_id == lobby_id
  end

  test "ban multiple", %{host: host, player: player1, hsocket: hsocket, lobby_id: lobby_id} do
    %{user: player2} = tachyon_auth_setup()
    %{user: player3} = tachyon_auth_setup()

    # Add player2 to the battle but not player 3
    Lobby.add_user_to_battle(player2.id, lobby_id, "script_password")
    Account.merge_update_client(player1.id, %{player: true})
    Account.merge_update_client(player2.id, %{player: true})

    player1_client = Account.get_client_by_id(player1.id)
    player2_client = Account.get_client_by_id(player2.id)
    assert player1_client.player == true
    assert player1_client.lobby_id == lobby_id
    assert player2_client.lobby_id == lobby_id

    data = %{
      cmd: "c.lobby.message",
      message:
        "$lobbybanmult #{player1.name} #{player2.name} #{player3.name} no_player_of_this_name"
    }

    _tachyon_send(hsocket, data)

    player1_client = Account.get_client_by_id(player1.id)
    player2_client = Account.get_client_by_id(player2.id)
    assert player1_client.lobby_id == nil
    assert player2_client.lobby_id == nil

    # Check ban state
    bans = Coordinator.call_consul(lobby_id, {:get, :bans})

    assert bans == %{
             player1.id => %{by: host.id, level: :banned, reason: "Banned"},
             player2.id => %{by: host.id, level: :banned, reason: "Banned"},
             player3.id => %{by: host.id, level: :banned, reason: "Banned"}
           }

    # Now unban player 3
    data = %{cmd: "c.lobby.message", message: "$unban #{player3.name}"}
    _tachyon_send(hsocket, data)

    bans = Coordinator.call_consul(lobby_id, {:get, :bans})

    assert bans == %{
             player1.id => %{by: host.id, level: :banned, reason: "Banned"},
             player2.id => %{by: host.id, level: :banned, reason: "Banned"}
           }

    # Now test it with a reason given
    data = %{
      cmd: "c.lobby.message",
      message:
        "$lobbybanmult #{player1.name} #{player2.name} #{player3.name} no_player_of_this_name !! Reason given is xyz"
    }

    _tachyon_send(hsocket, data)

    bans = Coordinator.call_consul(lobby_id, {:get, :bans})

    assert bans == %{
             player1.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"},
             player2.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"},
             player3.id => %{by: host.id, level: :banned, reason: "Reason given is xyz"}
           }
  end

  test "set_player_limit", %{lobby_id: lobby_id, hsocket: hsocket, host: host} do
    player_limit = Coordinator.call_consul(lobby_id, {:get, :player_limit})
    assert player_limit == 16

    data = %{cmd: "c.lobby.message", message: "$playerlimit 16"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.say",
             "lobby_id" => lobby_id,
             "message" => "$playerlimit 16",
             "sender_id" => host.id
           }

    # Check state
    player_limit = Coordinator.call_consul(lobby_id, {:get, :player_limit})
    assert player_limit == 16
  end

  test "roll", %{hsocket: hsocket, host: host} do
    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$roll badly"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.received_lobby_direct_announce"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()

    assert reply["message"] ==
             "Format not recognised, please consult the help for this command for more information."

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$roll 1D1"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == "#{host.name} rolled 1D1 and got a result of: 1"

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$roll 50D1"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] == "#{host.name} rolled 50D1 and got a result of: 50"

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$roll 100"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] =~ "#{host.name} rolled for a number between 1 and 100, they got: "

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$roll 20 100"})
    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.lobby.say"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] =~ "#{host.name} rolled for a number between 20 and 100, they got: "
  end

  test "status", %{lobby_id: lobby_id, hsocket: hsocket} do
    data = %{cmd: "c.lobby.message", message: "$status"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.received_direct_message"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()

    assert reply["message"] |> String.split("\n") |> Enum.slice(0, 5) == [
             "--------------------------- Lobby status ---------------------------",
             "Status for battle ##{lobby_id}",
             "Locks: ",
             "Gatekeeper: default",
             "Join queue:  (size: 0)"
           ]
  end

  test "help", %{lobby_id: lobby_id, hsocket: hsocket, host: host} do
    data = %{cmd: "c.lobby.message", message: "$help"}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.say",
             "lobby_id" => lobby_id,
             "message" => "$help",
             "sender_id" => host.id
           }

    [reply] = _tachyon_recv(hsocket)
    assert reply["cmd"] == "s.communication.received_direct_message"
    assert reply["sender_id"] == Coordinator.get_coordinator_userid()
    assert reply["message"] |> String.split("\n") |> Enum.count() > 5
  end

  test "rename", %{lobby_id: lobby_id, hsocket: hsocket, host: host} do
    data = %{cmd: "c.lobby.message", message: "$rename New Lobby Name::?  "}
    _tachyon_send(hsocket, data)

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.update_values",
             "lobby_id" => lobby_id,
             "new_values" => %{
               "name" => "New Lobby Name::?"
             }
           }

    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.say",
             "message" => "$rename New Lobby Name::?",
             "sender_id" => host.id,
             "lobby_id" => lobby_id
           }

    assert Battle.get_lobby(lobby_id).name == "New Lobby Name::?"
  end

  test "password? weth no password", %{lobby_id: lobby_id, hsocket: hsocket} do
    coordinator_id = Coordinator.get_coordinator_userid()

    _tachyon_send(hsocket, %{cmd: "c.lobby.message", message: "$password?"})
    [reply] = _tachyon_recv(hsocket)

    assert reply == %{
             "cmd" => "s.lobby.received_lobby_direct_announce",
             "message" => "This lobby has no password set",
             "sender_id" => coordinator_id
           }

    assert Battle.get_lobby(lobby_id).password == nil
    assert Battle.get_lobby(lobby_id).passworded == false
  end

  test "passthrough", %{hsocket: hsocket, listener: listener} do
    PubsubListener.get(listener)

    data = %{cmd: "c.lobby.message", message: "$non-existing command"}
    _tachyon_send(hsocket, data)
    messages = PubsubListener.get(listener)
    assert messages == []

    reply = _tachyon_recv(hsocket)

    assert reply == [
             %{
               "cmd" => "s.lobby.received_lobby_direct_announce",
               "message" => "No command of name 'non-existing'",
               "sender_id" => Coordinator.get_coordinator_userid()
             }
           ]
  end

  test "join_queue", %{
    lobby_id: lobby_id,
    host: host,
    hsocket: hsocket,
    psocket: _psocket,
    player: player
  } do
    consul_pid = Coordinator.get_consul_pid(lobby_id)

    # We don't want to use the player we start with, we want to number our players specifically
    Lobby.remove_user_from_any_lobby(player.id)

    _tachyon_send(hsocket, %{
      cmd: "c.lobby_host.update_host_status",
      boss: nil,
      teamsize: 2,
      teamcount: 2
    })

    state = Coordinator.call_consul(lobby_id, :get_all)
    max_player_count = ConsulServer.get_max_player_count(state)
    assert max_player_count == 4

    # At the moment we are hard coding the join queue to 8v8s until we
    # add something to get the player count limit
    ps1 = %{user: player1, socket: _socket1} = tachyon_auth_setup()
    ps2 = %{user: player2, socket: _socket2} = tachyon_auth_setup()
    ps3 = %{user: player3, socket: _socket3} = tachyon_auth_setup()
    ps4 = %{user: player4, socket: _socket4} = tachyon_auth_setup()

    %{user: player5, socket: socket5} = tachyon_auth_setup()
    %{user: player6, socket: socket6} = tachyon_auth_setup()
    %{user: player7, socket: socket7} = tachyon_auth_setup()
    %{user: player8, socket: _socket8} = tachyon_auth_setup()

    # The 50ms delays are to allow it to add them in the correct order
    [ps1, ps2, ps3, ps4]
    |> Enum.each(fn %{user: user, socket: socket} ->
      Lobby.force_add_user_to_lobby(user.id, lobby_id)
      :timer.sleep(50)
      _tachyon_send(socket, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})
    end)

    Lobby.force_add_user_to_lobby(player5.id, lobby_id)
    :timer.sleep(50)
    Lobby.force_add_user_to_lobby(player6.id, lobby_id)
    :timer.sleep(50)
    Lobby.force_add_user_to_lobby(player7.id, lobby_id)
    :timer.sleep(50)
    Lobby.force_add_user_to_lobby(player8.id, lobby_id)
    :timer.sleep(50)

    member_ids = Battle.get_lobby_member_list(lobby_id)

    assert member_ids == [
             player8.id,
             player7.id,
             player6.id,
             player5.id,
             player4.id,
             player3.id,
             player2.id,
             player1.id
           ]

    player_ids =
      Battle.list_lobby_players(lobby_id)
      |> Enum.map(fn %{userid: userid} -> userid end)

    assert player_ids == [player4.id, player3.id, player2.id, player1.id]

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == []

    # # Add to the queue
    _tachyon_send(socket5, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket6, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket7, %{cmd: "c.lobby.message", message: "$joinq"})

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player5.id, player6.id, player7.id]

    # Now leave the queue
    _tachyon_send(socket6, %{cmd: "c.lobby.message", message: "$leaveq"})
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player5.id, player7.id]

    # And the battle
    _tachyon_send(socket7, %{cmd: "c.lobby.leave"})
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player5.id]

    # Now we need one of the players to become a spectator and open up a slot!
    assert Account.get_client_by_id(player5.id).player == false

    _tachyon_send(ps1.socket, %{
      cmd: "c.lobby.update_status",
      client: %{player: false, ready: false}
    })

    :timer.sleep(100)
    send(consul_pid, :tick)

    consul_state = :sys.get_state(consul_pid)
    assert consul_state.join_queue == []
    assert Account.get_client_by_id(player5.id).player == true

    # Now get users 6 and 7 back in
    Lobby.force_add_user_to_lobby(player6.id, lobby_id)
    Lobby.force_add_user_to_lobby(player7.id, lobby_id)

    # Joinq again
    _tachyon_send(socket5, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket6, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket7, %{cmd: "c.lobby.message", message: "$joinq"})

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player6.id, player7.id]

    # Make player2 not a player
    _tachyon_send(ps2.socket, %{
      cmd: "c.lobby.update_status",
      client: %{player: false, ready: false}
    })

    # Shouldn't be an update just yet
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player6.id, player7.id]

    # Call the tick function, 6 is now a player so should be removed from the queue
    Coordinator.cast_consul(lobby_id, :tick)

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player7.id]

    # Finally we want to test the VIP command
    # Clear the messages from the host socket
    _tachyon_recv_until(hsocket)

    data = %{cmd: "c.lobby.message", message: "$vip #{player8.name}"}
    _tachyon_send(hsocket, data)

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player8.id, player7.id]

    result = _tachyon_recv(hsocket)

    assert result == [
             %{
               "cmd" => "s.lobby.say",
               "lobby_id" => lobby_id,
               "message" => "$vip #{player8.name}",
               "sender_id" => host.id
             }
           ]

    result = _tachyon_recv(hsocket)

    assert result == [
             %{
               "cmd" => "s.lobby.announce",
               "lobby_id" => lobby_id,
               "message" => "#{host.name} placed #{player8.name} at the front of the join queue",
               "sender_id" => Coordinator.get_coordinator_userid()
             }
           ]

    # Now do it for #7
    data = %{cmd: "c.lobby.message", message: "$vip #{player7.name}"}
    _tachyon_send(hsocket, data)

    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player7.id, player8.id]
  end

  test "join_queue_on_full_game", %{lobby_id: lobby_id, hsocket: hsocket, player: existing_player} do
    # Limit player count to 2 (1v1)
    _tachyon_send(hsocket, %{
      cmd: "c.lobby_host.update_host_status",
      boss: nil,
      teamsize: 1,
      teamcount: 2
    })

    state = Coordinator.call_consul(lobby_id, :get_all)
    max_player_count = ConsulServer.get_max_player_count(state)
    assert max_player_count == 2

    Lobby.kick_user_from_battle(existing_player.id, lobby_id)

    # Add the players
    %{user: player1, socket: socket1} = tachyon_auth_setup()
    %{user: player2, socket: socket2} = tachyon_auth_setup()
    %{user: player3, socket: socket3} = tachyon_auth_setup()

    Lobby.force_add_user_to_lobby(player1.id, lobby_id)
    Lobby.force_add_user_to_lobby(player2.id, lobby_id)
    Lobby.force_add_user_to_lobby(player3.id, lobby_id)
    :timer.sleep(50)

    # Players 2 and 3 are playing a 1v1, player 1 is a not a player
    _tachyon_send(socket1, %{cmd: "c.lobby.update_status", client: %{player: false, ready: false}})

    _tachyon_send(socket2, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})
    _tachyon_send(socket3, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})

    assert Account.get_client_by_id(player1.id).player == false
    assert Account.get_client_by_id(player2.id).player == true
    assert Account.get_client_by_id(player3.id).player == true

    # Queue should be empty at start
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == []

    # Player 1 now wants to join
    _tachyon_send(socket1, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})

    # And added to the join queue
    assert Account.get_client_by_id(player1.id).player == false
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player1.id]
  end

  test "shuffle", %{lobby_id: lobby_id, hsocket: hsocket, player: existing_player} do
    # Limit player count to 4 (2v2)
    _tachyon_send(hsocket, %{
      cmd: "c.lobby_host.update_host_status",
      boss: nil,
      teamsize: 2,
      teamcount: 2
    })

    Lobby.kick_user_from_battle(existing_player.id, lobby_id)

    state = Coordinator.call_consul(lobby_id, :get_all)
    max_player_count = ConsulServer.get_max_player_count(state)
    assert max_player_count == 4

    # Add the players
    %{user: player1, socket: socket1} = tachyon_auth_setup()
    User.add_roles(player1.id, ["VIP", "Streamer"])

    %{user: player2, socket: socket2} = tachyon_auth_setup()
    %{user: player3, socket: socket3} = tachyon_auth_setup()
    %{user: player4, socket: socket4} = tachyon_auth_setup()
    %{user: player5, socket: socket5} = tachyon_auth_setup()
    %{user: player6, socket: socket6} = tachyon_auth_setup()
    %{user: player7, socket: socket7} = tachyon_auth_setup()
    %{user: player8, socket: socket8} = tachyon_auth_setup()
    %{user: player9, socket: socket9} = tachyon_auth_setup()

    Lobby.force_add_user_to_lobby(player1.id, lobby_id)
    Lobby.force_add_user_to_lobby(player2.id, lobby_id)
    Lobby.force_add_user_to_lobby(player3.id, lobby_id)
    Lobby.force_add_user_to_lobby(player4.id, lobby_id)
    Lobby.force_add_user_to_lobby(player5.id, lobby_id)
    Lobby.force_add_user_to_lobby(player6.id, lobby_id)
    Lobby.force_add_user_to_lobby(player7.id, lobby_id)
    Lobby.force_add_user_to_lobby(player8.id, lobby_id)
    Lobby.force_add_user_to_lobby(player9.id, lobby_id)
    :timer.sleep(1000)

    # All of them want to be players
    _tachyon_send(socket1, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket2, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket3, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket4, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket5, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket6, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket7, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket8, %{cmd: "c.lobby.message", message: "$joinq"})
    _tachyon_send(socket9, %{cmd: "c.lobby.message", message: "$joinq"})
    :timer.sleep(1000)

    assert Account.get_client_by_id(player1.id).player == true
    assert Account.get_client_by_id(player2.id).player == true
    assert Account.get_client_by_id(player3.id).player == true
    assert Account.get_client_by_id(player4.id).player == true

    assert Account.get_client_by_id(player5.id).player == false
    assert Account.get_client_by_id(player6.id).player == false
    assert Account.get_client_by_id(player7.id).player == false
    assert Account.get_client_by_id(player8.id).player == false
    assert Account.get_client_by_id(player9.id).player == false

    player_list =
      Teiserver.Coordinator.ConsulServer.list_players(%{lobby_id: lobby_id})
      |> Enum.map(fn %{userid: userid} -> userid end)

    # Queue should be empty at start
    queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    assert queue == [player5.id, player6.id, player7.id, player8.id]

    # # Player 1 now wants to join
    # _tachyon_send(socket1, %{cmd: "c.lobby.update_status", client: %{player: true, ready: true}})

    # # And added to the join queue
    # assert Account.get_client_by_id(player1.id).player == false
    # queue = Coordinator.call_consul(lobby_id, {:get, :join_queue})
    # assert queue == [player1.id]
  end
end
