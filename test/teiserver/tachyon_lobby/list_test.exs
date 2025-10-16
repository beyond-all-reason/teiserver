defmodule Teiserver.TachyonLobby.ListTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until: 2]
  alias Teiserver.TachyonLobby, as: Lobby

  @moduletag :tachyon

  test "no lobbies" do
    assert Lobby.list() == %{}
  end

  test "register a lobby" do
    overview = overview_fixture()

    Lobby.List.register_lobby(self(), "lobby-id", overview)
    assert Lobby.list() == %{"lobby-id" => overview}
  end

  test "remove dead lobbies" do
    {:ok, pid} =
      Task.start(fn ->
        Lobby.List.register_lobby(self(), "lobby-id", overview_fixture())
        :timer.sleep(:infinity)
      end)

    poll_until(&Lobby.list/0, &(map_size(&1) == 1))
    assert %{"lobby-id" => _} = Lobby.list()
    Process.exit(pid, :kill)
    poll_until(&Lobby.list/0, &(map_size(&1) == 0))
  end

  test "update subscription" do
    assert {initial_counter, %{}} = Lobby.subscribe_updates()

    {:ok, pid} =
      Task.start(fn ->
        Lobby.List.register_lobby(self(), "lobby-id", overview_fixture())
        :timer.sleep(:infinity)
      end)

    assert_receive %{
                     topic: "teiserver_tachyonlobby_list",
                     event: :add_lobby,
                     lobby_id: "lobby-id"
                   } = ev

    assert ev.counter > initial_counter

    Process.exit(pid, :kill)

    assert_receive %{
                     topic: "teiserver_tachyonlobby_list",
                     event: :remove_lobby,
                     lobby_id: "lobby-id"
                   } = ev2

    assert ev2.counter > ev.counter
  end

  test "get updates when player joins or leaves teams" do
    {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

    {:ok, _pid, %{id: id}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Lobby.create()

    assert {_initial_counter, %{^id => _}} = Lobby.subscribe_updates()
    {:ok, _, _} = Lobby.join(id, %{id: "user2", name: "name-user2"}, sink_pid)
    {:ok, _details} = Lobby.join_ally_team(id, "user2", 1)
    assert_receive %{event: :update_lobby, lobby_id: ^id, changes: %{player_count: 2}}

    :ok = Lobby.leave(id, "user2")
    assert_receive %{event: :update_lobby, lobby_id: ^id, changes: %{player_count: 1}}
  end

  test "get updates when player dies" do
    {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

    {:ok, _pid, %{id: id}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Lobby.create()

    assert {_initial_counter, %{^id => _}} = Lobby.subscribe_updates()
    {:ok, _, _} = Lobby.join(id, %{id: "user2", name: "name-user2"}, sink_pid)
    {:ok, _details} = Lobby.join_ally_team(id, "user2", 1)
    assert_receive %{event: :update_lobby, lobby_id: ^id, changes: %{player_count: 2}}

    Process.exit(sink_pid, :exit)
    assert_receive %{event: :update_lobby, lobby_id: ^id, changes: %{player_count: 1}}
  end

  test "remove update when last player leaves" do
    {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

    {:ok, _pid, %{id: id}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Lobby.create()

    assert {_initial_counter, %{^id => _}} = Lobby.subscribe_updates()

    :ok = Lobby.leave(id, "1234")
    assert_receive %{lobby_id: ^id, event: :remove_lobby}
  end

  test "restore state on startup" do
    {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

    {:ok, pid1, %{id: id1}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Map.replace!(:name, "first lobby")
      |> Lobby.create()

    {:ok, pid2, %{id: id2}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Map.replace!(:name, "second lobby")
      |> Lobby.create()

    Supervisor.terminate_child(Lobby.System, Lobby.List)

    # While the list process is dead, terminate a lobby and create a new one
    Process.exit(pid1, :kill)

    {:ok, _pid, %{id: id3}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Map.replace!(:name, "third lobby")
      |> Lobby.create()

    assert {_initial_counter, %{}} = Lobby.subscribe_updates()
    Supervisor.restart_child(Lobby.System, Lobby.List)

    assert_receive %{event: :reset_list, lobbies: lobbies}
    assert not is_map_key(lobbies, id1), "first lobby is no more"
    assert is_map_key(lobbies, id2), "second lobby is there"
    assert is_map_key(lobbies, id3), "new lobby is registered"

    # and stopping a lobby after restart still works (aka, monitors are set up)
    Process.exit(pid2, :kill)
    assert_receive %{event: :remove_lobby, lobby_id: ^id2}
  end

  defp overview_fixture() do
    %{
      name: "lobby name",
      player_count: 1,
      max_player_count: 2,
      map_name: "new map",
      engine_version: "engine123",
      game_version: "game123"
    }
  end

  defp mk_start_params(teams) do
    %{
      creator_data: %{id: "1234", name: "name-1234"},
      creator_pid: self(),
      name: "test create lobby",
      map_name: "irrelevant map name",
      game_version: "fake game version",
      engine_version: "fake engine version",
      ally_team_config:
        Enum.map(teams, fn max_team ->
          x = for _ <- 1..max_team, do: %{max_players: 1}

          %{
            max_teams: max_team,
            start_box: %{top: 0, left: 0, bottom: 1, right: 0.2},
            teams: x
          }
        end)
    }
  end
end
