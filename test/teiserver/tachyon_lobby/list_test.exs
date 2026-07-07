defmodule Teiserver.TachyonLobby.ListTest do
  alias Teiserver.Support.Polling
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase

  import Teiserver.TachyonLobby.Lobby, only: [list_topic: 0]
  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 1]

  describe "list existing lobbies" do
    test "no lobbies" do
      assert Lobby.list() == %{}
    end

    test "list returns the overview" do
      params = mk_start_params([1, 1])
      {:ok, _pid, details} = Lobby.create(params)
      list = Lobby.list()

      assert list[details.id] == %LT.ListOverview{
               counter: 0,
               boss_enabled?: false,
               current_battle: nil,
               engine_version: params.engine_version,
               game_version: params.game_version,
               map_name: params.map_name,
               max_player_count: 2,
               name: params.name,
               player_count: 1,
               tags: %{}
             }
    end

    test "list multiple lobbies" do
      {:ok, _pid, details1} =
        mk_start_params([1, 1]) |> Lobby.create()

      {:ok, _pid, details2} =
        mk_start_params([1, 1]) |> Lobby.create()

      list = Lobby.list()
      assert map_size(list) == 2
      assert is_map_key(list, details1.id)
      assert is_map_key(list, details2.id)
    end

    @tag :capture_log
    test "remove dead lobbies" do
      creator_pid = start_supervised!({Task, fn -> :timer.sleep(:infinity) end})

      {:ok, _pid, details} =
        mk_start_params([1, 1])
        |> Map.put(:creator_pid, creator_pid)
        |> Lobby.create()

      id = details.id

      %{^id => %{}} = Lobby.list()
      Process.exit(creator_pid, :exit)
      Polling.poll_until(&Lobby.list/0, &(&1 == %{}))
    end

    test "update to lobbies reflected in list" do
      {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
      id = details.id
      initial_list = Lobby.list()

      {:ok, _lobby_pid, _join_details} = Lobby.join(details.id, mk_player("user2"))
      {:ok, _team_details} = Lobby.join_ally_team(details.id, "user2", 1)
      final_list = Polling.poll_until(&Lobby.list/0, &(&1[id].player_count == 2))
      assert final_list[id].counter > initial_list[id].counter
    end
  end

  describe "subscription" do
    test "subscribe gets the full list" do
      {:ok, _pid, _details} = mk_start_params([1, 1]) |> Lobby.create()
      list = Lobby.subscribe_updates()
      assert list == Lobby.list()
    end

    test "new lobby are broadcasted" do
      Lobby.subscribe_updates()
      {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()

      assert_receive %{event: :add_lobby, overview: %LT.ListOverview{}, lobby_id: lobby_id}

      assert lobby_id == details.id
    end

    test "lobby changes are broadcasted" do
      {:ok, _pid, details} = mk_start_params([1, 1]) |> Lobby.create()
      list = Lobby.subscribe_updates()
      {:ok, _lobby_pid, _join_details} = Lobby.join(details.id, mk_player("user2"))
      {:ok, _team_details} = Lobby.join_ally_team(details.id, "user2", 1)

      id = details.id
      assert_receive %{event: :update_lobby, changes: changes, counter: counter, lobby_id: ^id}
      assert changes == %{player_count: 2}
      assert counter > list[details.id].counter
    end

    test "get event when lobby dies" do
      creator_pid = start_supervised!({Task, fn -> :timer.sleep(:infinity) end})

      {:ok, _pid, details} =
        mk_start_params([1, 1])
        |> Map.put(:creator_pid, creator_pid)
        |> Lobby.create()

      Lobby.subscribe_updates()
      Process.exit(creator_pid, :exit)

      topic = list_topic()
      id = details.id
      assert_receive %{topic: ^topic, event: :remove_lobby, lobby_id: ^id}
    end

    test "monitors setup after list restart" do
      creator_pid = start_supervised!({Task, fn -> :timer.sleep(:infinity) end})

      {:ok, _pid, details} =
        mk_start_params([1, 1])
        |> Map.put(:creator_pid, creator_pid)
        |> Lobby.create()

      Lobby.subscribe_updates()

      orig_list_pid = Process.whereis(Lobby.ListMonitor)
      Process.exit(orig_list_pid, :kill)

      Polling.poll_until(
        fn -> Process.whereis(Lobby.ListMonitor) end,
        &(&1 != nil and &1 != orig_list_pid)
      )

      Process.exit(creator_pid, :exit)

      topic = list_topic()
      id = details.id
      assert_receive %{topic: ^topic, event: :remove_lobby, lobby_id: ^id}
    end

    test "can unsubscribe" do
      Lobby.subscribe_updates()
      {:ok, _pid, _details} = mk_start_params([1, 1]) |> Lobby.create()
      topic = list_topic()
      assert_receive %{topic: ^topic}

      Lobby.unsubscribe_updates()
      {:ok, _pid, _details} = mk_start_params([1, 1]) |> Lobby.create()
      refute_receive %{topic: ^topic}
    end
  end

  defp mk_player(user_id) do
    %LT.PlayerJoinData{id: user_id, name: "name-#{user_id}"}
  end
end
