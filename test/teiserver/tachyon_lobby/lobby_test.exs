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

    test "lobby full" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))

      for i <- 1..250 do
        {:ok, _, _} = Lobby.join(id, mk_player("user#{i}"), sink_pid)
      end

      # there should be 250 specs and 1 player now, which is the absolute limit
      {:error, :lobby_full} = Lobby.join(id, mk_player("user251"), sink_pid)

      # user already in the lobby are still fine
      {:ok, _, _} = Lobby.join(id, mk_player("user10"), sink_pid)
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

    test "can leave lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), self())
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user3"), self())
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user4"), self())

      {:ok, _details} = Lobby.join_ally_team(id, "user3", 1)
      {:ok, details} = Lobby.join_ally_team(id, "user4", 1)

      # user 3 and 4 should be on the same team
      assert details.players["user3"].team == {1, 0, 0}
      assert details.players["user4"].team == {1, 1, 0}
      :ok = Lobby.leave(id, "user3")

      # join again to get the details
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user3"), self())
      {:ok, details} = Lobby.join_ally_team(id, "user3", 1)
      assert details.players["user4"].team == {1, 0, 0}
      assert details.players["user3"].team == {1, 1, 0}
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

    test "spec leaving removes monitors" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, lobby_pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}

      :ok = Lobby.leave(id, "user2")
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}
      Process.exit(sink_pid, :kill)
      refute_receive _, 30
      assert Process.alive?(lobby_pid)
    end

    test "player leaving removes monitors" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, lobby_pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}
      {:ok, _details} = Lobby.join_ally_team(id, "user2", 1)
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}

      :ok = Lobby.leave(id, "user2")
      assert_receive {:lobby, ^id, {:updated, [%{event: :updated}]}}
      Process.exit(sink_pid, :kill)
      refute_receive _, 30
      assert Process.alive?(lobby_pid)
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

  describe "join queue" do
    test "with invalid lobby" do
      {:error, :invalid_lobby} = Lobby.join_queue("not-a-lobby", "user1")
    end

    test "not in lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:error, :not_in_lobby} = Lobby.join_queue(id, "not in lobby")
    end

    test "can immediately join when spot available" do
      %{id: id} = setup_full_lobby()
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{players: %{"2" => %{team: {1, 0, 0}}}} = updates
    end

    test "doesn't queue if spaces are available" do
      %{id: id} = setup_full_lobby()
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      {:ok, details} = Teiserver.TachyonLobby.Lobby.get_details(id)
      assert is_map_key(details.players, "2")
      assert %{players: %{"2" => %{team: {1, 0, 0}}}} = updates
      :ok = Lobby.join_queue(id, "2")
      refute_receive _, 30
    end

    test "player can join the back of the queue" do
      %{id: id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: _}]}}
      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      %{spectators: %{"3" => %{join_queue_position: pos}}} = updates

      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}

      # player 2 is at the back of the queue now
      assert %{spectators: %{"2" => %{join_queue_position: pos2}}} = updates
      assert pos2 > pos
      # and player 3 is now playing
      %{spectators: %{"3" => nil}, players: %{"3" => %{}}} = updates
    end

    test "join wait queue when full" do
      %{id: id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      :ok = Lobby.join_queue(id, "4")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"4" => %{join_queue_position: 2}}} = updates
    end

    test "when in queue calling again does nothing" do
      %{id: id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      # joining the queue again should not change anything
      :ok = Lobby.join_queue(id, "3")
      refute_receive _, 30
      {:ok, details} = Teiserver.TachyonLobby.Lobby.get_details(id)
      assert details.spectators["3"].join_queue_position == 1
    end

    test "join team when player become spectator" do
      %{id: id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      :ok = Lobby.spectate(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}

      assert %{spectators: %{"3" => nil}, players: %{"3" => %{team: {1, 0, 0}}}} = updates
    end

    test "join team when player leaves the lobby" do
      %{id: id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      :ok = Lobby.leave(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}

      assert %{players: %{"2" => nil, "3" => %{team: {1, 0, 0}}}} = updates
    end

    test "join team when player disappear" do
      %{id: id} = ctx = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      Process.unlink(ctx[:users]["2"].pid)
      Process.exit(ctx[:users]["2"].pid, :kill)
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}

      assert %{players: %{"3" => %{team: {1, 0, 0}}, "2" => nil}} = updates
    end

    test "spec queue positions works" do
      %{id: id} = ctx = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, "3")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"3" => %{join_queue_position: 1}}} = updates

      :ok = Lobby.join_queue(id, "4")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"4" => %{join_queue_position: 2}}} = updates

      # make sure that user2 rejoining is put at the back of the queue
      :ok = Lobby.leave(id, "2")
      assert_receive {:lobby, ^id, {:updated, _}}
      {:ok, _, _} = Lobby.join(id, ctx.users["2"])
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.join_queue(id, "2")
      assert_receive {:lobby, ^id, {:updated, [%{updates: updates}]}}
      assert %{spectators: %{"2" => %{join_queue_position: 3}}} = updates
    end
  end

  # these tests are a bit anemic because they also require a connected autohost
  # and it's a lot of setup. There are some end to end tests in the
  # teiserver_web/tachyon/lobby_test.exs file
  # though this section could also be expanded
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

  # create a lobby with a few specs already in. Simplify the logic when
  # it comes to testing in-lobby interaction
  defp setup_full_lobby(teams \\ [2, 2]) do
    {:ok, lobby_pid, %{id: id}} = mk_start_params(teams) |> Lobby.create()

    users =
      Enum.map([2, 3, 4, 5], fn i ->
        {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
        player_id = to_string(i)
        player = mk_player(player_id)
        {:ok, _, _details} = Lobby.join(id, player, sink_pid)
        {to_string(i), Map.put(player, :pid, sink_pid)}
      end)
      |> Map.new()

    {:ok, details} = Teiserver.TachyonLobby.Lobby.get_details(id)
    assert map_size(details.players) == 1
    assert map_size(details.spectators) == 4

    # after getting the details, it should be guaranteed that all updates are
    # in the inbox, so no need to wait
    drain_msg_queue()

    %{lobby_pid: lobby_pid, id: id, users: users, details: details}
  end

  defp drain_msg_queue(timeout \\ 0, acc \\ []) do
    receive do
      msg -> drain_msg_queue(timeout, [msg | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end
end
