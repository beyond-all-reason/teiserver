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

  test "get updates when player joins lobby" do
    {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

    {:ok, _pid, %{id: id}} =
      mk_start_params([2, 2])
      |> Map.replace!(:creator_pid, sink_pid)
      |> Lobby.create()

    assert {_initial_counter, %{^id => _}} = Lobby.subscribe_updates()
    {:ok, _, _} = Lobby.join(id, "user2", sink_pid)
    assert_receive %{event: :update_lobby, lobby_id: ^id, changes: %{player_count: 2}}
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
      creator_user_id: "1234",
      creator_pid: self(),
      name: "test create lobby",
      map_name: "irrelevant map name",
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
