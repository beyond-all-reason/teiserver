defmodule Teiserver.TachyonLobby.LobbyTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1, poll_until_nil: 1]
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.AssetFixtures

  @moduletag :tachyon

  @default_user_id "1234"

  test "create a lobby" do
    {:ok, pid, details} = Lobby.create(mk_start_params([1, 1]))
    p = poll_until_some(fn -> Lobby.lookup(details.id) end)
    assert p == pid
  end

  test "must have a game in db" do
    result =
      mk_start_params([1, 1])
      |> Map.drop([:game_version])
      |> Lobby.create()

    assert result == {:error, :no_game_version_found}
  end

  test "get default game from db" do
    game = AssetFixtures.create_game(%{name: "test-game", in_matchmaking: true})

    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.drop([:game_version])
      |> Lobby.create()

    assert details.game_version == game.name
  end

  test "must have engine in db" do
    result =
      mk_start_params([1, 1])
      |> Map.drop([:engine_version])
      |> Lobby.create()

    assert result == {:error, :no_engine_version_found}
  end

  test "get default engine from db" do
    engine = AssetFixtures.create_engine(%{name: "test-engine", in_matchmaking: true})

    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.drop([:engine_version])
      |> Lobby.create()

    assert details.engine_version == engine.name
  end

  test "exit when no more players" do
    test_pid = self()

    {:ok, pid} =
      Task.start(fn ->
        {:ok, _pid, details} = Lobby.create(mk_start_params([1, 1]))
        send(test_pid, {:lobby_id, details.id})

        :timer.sleep(:infinity)
      end)

    assert_receive {:lobby_id, lobby_id}
    poll_until_some(fn -> Lobby.lookup(lobby_id) end)

    Process.exit(pid, :kill)
    poll_until_nil(fn -> Lobby.lookup(lobby_id) end)
  end

  describe "joining" do
    test "invalid lobby" do
      assert {:error, :invalid_lobby} == Lobby.join("nope", mk_player("user-id"), self())
    end

    test "as a spectator" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _, details} = Lobby.join(id, mk_player("other-user-id"), sink_pid)
      assert details.spectators["other-user-id"].join_queue_position == nil

      assert_receive {:lobby, ^id,
                      {:updated,
                       [
                         %{
                           event: :updated,
                           updates: %{
                             spectators: %{"other-user-id" => %{join_queue_position: nil}}
                           }
                         }
                       ]}}
    end

    test "is idempotent" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 1]))
      {:ok, _, details} = Lobby.join(id, mk_player("other-user-id"), self())
      {:ok, _, details2} = Lobby.join(id, mk_player("other-user-id"), self())
      assert details == details2
    end

    test "participants get updated events on join" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)

      assert_receive {:lobby, ^id,
                      {:updated,
                       [
                         %{
                           event: :updated,
                           updates: %{spectators: %{"user2" => %{join_queue_position: nil}}}
                         }
                       ]}}

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)

      expected_updates = %{spectators: %{"user2" => %{join_queue_position: nil}}}

      assert_receive {:lobby, ^id, {:updated, [%{event: :updated, updates: ^expected_updates}]}}
    end
  end

  describe "joining an ally team" do
    test "must be valid lobby" do
      {:error, :invalid_lobby} = Lobby.join_ally_team("nope", "user", 0)
    end

    test "must be in lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))
      {:error, :not_in_lobby} = Lobby.leave(id, "not here")
    end

    test "must target valid ally team" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"))
      {:error, :invalid_ally_team} = Lobby.join_ally_team(id, "user2", 2)
    end

    test "ally team must have empty space" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"))
      {:error, :ally_team_full} = Lobby.join_ally_team(id, "user2", 0)
    end

    test "works" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      {:ok, details} = Lobby.join_ally_team(id, "user2", 1)
      assert %{team: {1, _, _}} = details.players["user2"]

      # is idempotent
      {:ok, details2} = Lobby.join_ally_team(id, "user2", 1)
      assert details == details2
    end

    test "player moving also get updates" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %{id: id}} =
        mk_start_params([1, 1]) |> Map.put(:creator_pid, sink_pid) |> Lobby.create()

      {:ok, _, _details} = Lobby.join(id, mk_player("user2"))
      {:ok, _details} = Lobby.join_ally_team(id, "user2", 1)

      expected = %{
        event: :updated,
        updates: %{
          players: %{"user2" => %{team: {1, 0, 0}}},
          spectators: %{"user2" => nil}
        }
      }

      assert_receive {:lobby, ^id, {:updated, [^expected]}}
    end

    test "can change ally team" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      {:ok, details} = Lobby.join_ally_team(id, "user2", 1)
      assert %{team: {1, _, _}} = details.players["user2"]

      {:ok, details} = Lobby.join_ally_team(id, "user2", 0)
      assert %{team: {0, _, _}} = details.players["user2"]
    end

    test "other players are reshuffled" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_receive _

      {:ok, details} = Lobby.join_ally_team(id, "user2", 0)

      expected_update = %{
        players: %{"user2" => %{team: {0, 1, 0}}},
        spectators: %{"user2" => nil}
      }

      assert_receive {:lobby, ^id, {:updated, [%{event: :updated, updates: ^expected_update}]}}

      assert %{team: {0, _, _}} = details.players["user2"]

      # moving from ally team 0 to 1 should reorder "user2" in the first ally team
      {:ok, details} = Lobby.join_ally_team(id, @default_user_id, 1)
      %{@default_user_id => %{team: {1, 0, 0}}, "user2" => %{team: {0, 0, 0}}} = details.players
    end
  end

  describe "leaving" do
    test "cannot leave lobby if not in the lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 1]))
      {:error, :not_in_lobby} = Lobby.leave(id, "not here")
    end

    test "cannot leave lobby if already left" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 1]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), self())
      :ok = Lobby.leave(id, "user2")
      {:error, :not_in_lobby} = Lobby.leave(id, "user2")
    end

    @tag :skip
    test "can leave lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), self())
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user3"), self())
      {:ok, _pid, details} = Lobby.join(id, mk_player("user4"), self())

      # user 2 and 4 should be on the same team
      assert details.members["user2"].team == {1, 0, 0}
      assert details.members["user4"].team == {1, 1, 0}
      :ok = Lobby.leave(id, "user2")

      # join again to get the details
      {:ok, _pid, details} = Lobby.join(id, mk_player("user2"), self())
      assert details.members["user4"].team == {1, 0, 0}
      assert details.members["user2"].team == {1, 1, 0}
    end

    test "can leave lobby and rejoin" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      player = mk_player("user2")
      {:ok, _pid, _details} = Lobby.join(id, player, self())
      :ok = Lobby.leave(id, "user2")
      {:ok, _pid, _details} = Lobby.join(id, player, self())
    end

    test "leaving lobby send updates to remaining members" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}

      :ok = Lobby.leave(id, "user2")
      expected = %{spectators: %{"user2" => nil}}
      assert_received {:lobby, ^id, {:updated, [%{event: :updated, updates: ^expected}]}}
    end

    test "reshuffling player on leave sends updates" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user3"), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user4"), sink_pid)

      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}
      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}
      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}

      {:ok, _details} = Lobby.join_ally_team(id, "user2", 1)
      {:ok, _details} = Lobby.join_ally_team(id, "user3", 1)

      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}
      assert_received {:lobby, ^id, {:updated, [%{event: :updated}]}}

      :ok = Lobby.leave(id, "user2")

      expected_event = %{
        event: :updated,
        updates: %{players: %{"user2" => nil, "user3" => %{team: {1, 0, 0}}}}
      }

      assert_received {:lobby, ^id, {:updated, [^expected_event]}}
    end

    test "player pid dying means player is removed from lobby" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, _pid, %{id: id}} =
        mk_start_params([2, 2]) |> Map.put(:creator_pid, sink_pid) |> Lobby.create()

      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), self())
      Process.exit(sink_pid, :kill)

      assert_receive {:lobby, ^id,
                      {:updated, [%{event: :updated, updates: %{players: %{"1234" => nil}}}]}}
    end

    test "spectator pid dying means is removed from lobby" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}

      Process.exit(sink_pid, :kill)

      assert_receive {:lobby, ^id,
                      {:updated, [%{event: :updated, updates: %{spectators: %{"user2" => nil}}}]}}
    end
  end

  describe "spectate" do
    test "must target valid lobby" do
      {:error, :invalid_lobby} = Lobby.spectate("nolobby", "user1")
    end

    test "must be in lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:error, :not_in_lobby} = Lobby.spectate(id, "not in lobby")
    end

    test "works" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      :ok = Lobby.spectate(id, @default_user_id)

      expected = %{
        players: %{@default_user_id => nil},
        spectators: %{@default_user_id => %{join_queue_position: nil}}
      }

      assert_receive {:lobby, ^id, {:updated, [%{event: :updated, updates: ^expected}]}}
    end

    test "is idempotent" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      :ok = Lobby.spectate(id, @default_user_id)
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.spectate(id, @default_user_id)
      refute_receive _, 30
    end
  end

  describe "start battle" do
    test "lobby must be valid" do
      {:error, :invalid_lobby} = Lobby.start_battle("nolobby", "user1")
    end

    test "must be in lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:error, :not_in_lobby} = Lobby.start_battle(id, "not in lobby")
    end
  end

  describe "start script" do
    test "with 1 player" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      start_script = Teiserver.TachyonLobby.Lobby.get_start_script(id)
      %{allyTeams: [%{teams: [%{players: [%{userId: @default_user_id}]}]}]} = start_script
    end

    test "with a spec" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("other-user-id"))

      start_script = Teiserver.TachyonLobby.Lobby.get_start_script(id)
      %{spectators: [%{userId: "other-user-id"}]} = start_script
    end

    test "with 2 players in the same team" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("other-user-id"))
      {:ok, _} = Lobby.join_ally_team(id, "other-user-id", 0)

      start_script = Teiserver.TachyonLobby.Lobby.get_start_script(id)
      %{allyTeams: [%{teams: [t1, t2]}]} = start_script
      %{players: [%{userId: @default_user_id}]} = t1
      %{players: [%{userId: "other-user-id"}]} = t2
    end

    test "1 ally team with a player leaving then joining" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("other-user-id"))
      {:ok, _} = Lobby.join_ally_team(id, "other-user-id", 0)
      :ok = Lobby.spectate(id, @default_user_id)
      {:ok, _} = Lobby.join_ally_team(id, @default_user_id, 0)

      start_script = Teiserver.TachyonLobby.Lobby.get_start_script(id)
      %{allyTeams: [%{teams: [t1, t2]}]} = start_script
      %{players: [%{userId: "other-user-id"}]} = t1
      %{players: [%{userId: @default_user_id}]} = t2
    end

    test "2 ally teams" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("other-user-id"))
      {:ok, _} = Lobby.join_ally_team(id, "other-user-id", 1)

      start_script = Teiserver.TachyonLobby.Lobby.get_start_script(id)
      %{allyTeams: [%{teams: [t1]}, %{teams: [t2]}]} = start_script
      %{players: [%{userId: @default_user_id}]} = t1
      %{players: [%{userId: "other-user-id"}]} = t2
    end
  end

  defp mk_start_params(teams) do
    %{
      creator_data: %{id: @default_user_id, name: "name-#{@default_user_id}"},
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

  defp mk_player(user_id) do
    %{id: user_id, name: "name-#{user_id}"}
  end
end
