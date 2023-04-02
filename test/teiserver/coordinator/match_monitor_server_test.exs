defmodule Teiserver.Coordinator.MatchMonitorServerTest do
  use Central.ServerCase, async: false
  alias Teiserver.{User, Chat, Client}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Coordinator.{CoordinatorServer}

  import Teiserver.TeiserverTestLib,
    only: [tachyon_auth_setup: 0, _tachyon_send: 2, _tachyon_recv: 1]

  setup do
    account = CoordinatorServer.get_coordinator_account()
    Central.cache_put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    Teiserver.Battle.start_match_monitor()
    %{socket: hsocket, user: host} = tachyon_auth_setup()
    %{socket: psocket, user: player} = tachyon_auth_setup()
    User.update_user(%{host | bot: true})

    battle_data = %{
      cmd: "c.lobby.create",
      name: "MonitorMatch #{:rand.uniform(999_999_999)}",
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

    data = %{cmd: "c.lobby.create", lobby: battle_data}
    _tachyon_send(hsocket, data)
    [reply] = _tachyon_recv(hsocket)
    lobby_id = reply["lobby"]["id"]

    # Player needs to be added to the battle
    Lobby.force_add_user_to_lobby(player.id, lobby_id)
    :timer.sleep(100)
    player_client = Client.get_client_by_id(player.id)

    Client.update(
      %{player_client | player: true, ready: true},
      :client_updated_battlestatus
    )

    # Add user message
    _tachyon_recv(hsocket)

    # Battlestatus message
    _tachyon_recv(hsocket)

    {:ok, hsocket: hsocket, psocket: psocket, host: host, player: player, lobby_id: lobby_id}
  end

  test "chat messages", %{hsocket: hsocket, host: host, player: player} do
    monitor_user = User.get_user_by_name("AutohostMonitor")
    messages1 = Chat.list_lobby_messages(search: [user_id: host.id])
    messages2 = Chat.list_lobby_messages(search: [user_id: player.id])

    assert Enum.empty?(messages1)
    assert Enum.empty?(messages2)

    _tachyon_send(hsocket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{player.name}> dallies: Allied chat message"
    })

    :timer.sleep(100)

    messages1 = Chat.list_lobby_messages(search: [user_id: host.id])
    messages2 = Chat.list_lobby_messages(search: [user_id: player.id])

    assert Enum.empty?(messages1)
    assert Enum.count(messages2) == 1

    _tachyon_send(hsocket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{player.name}> d: Game chat message"
    })

    :timer.sleep(100)

    messages1 = Chat.list_lobby_messages(search: [user_id: host.id])
    messages2 = Chat.list_lobby_messages(search: [user_id: player.id])

    assert Enum.empty?(messages1)
    assert Enum.count(messages2) == 1

    _tachyon_send(hsocket, %{
      "cmd" => "c.communication.send_direct_message",
      "recipient_id" => monitor_user.id,
      "message" => "match-chat <#{player.name}> dspectators: Spec chat message"
    })

    :timer.sleep(100)

    messages1 = Chat.list_lobby_messages(search: [user_id: host.id])
    messages2 = Chat.list_lobby_messages(search: [user_id: player.id])

    assert Enum.empty?(messages1)
    assert Enum.count(messages2) == 2

    [allied, spectator] = messages2

    assert match?(
             %{
               content: "a: Allied chat message"
             },
             allied
           )

    # assert match?(%{
    #   content: "g: Game chat message"
    # }, game)
    assert match?(
             %{
               content: "s: Spec chat message"
             },
             spectator
           )

    # _tachyon_send(hsocket, %{
    #   "cmd" => "c.communication.send_direct_message",
    #   "recipient_id" => monitor_user.id,
    #   "message" => "match-chat <#{player.name}> d123: Direct chat message"
    # })
  end
end
