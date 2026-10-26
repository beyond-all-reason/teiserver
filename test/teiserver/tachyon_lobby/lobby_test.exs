defmodule Teiserver.TachyonLobby.LobbyTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.AssetFixtures
  alias Teiserver.Autohost.Types, as: AT
  alias Teiserver.Player.SessionRegistry
  alias Teiserver.TachyonLobby, as: Lobby
  alias Teiserver.TachyonLobby.Lobby, as: LobbyProcess
  alias Teiserver.TachyonLobby.Types, as: LT

  use Teiserver.DataCase

  import Teiserver.Support.LobbyHelpers, only: [mk_start_params: 1, mk_start_params: 2]
  import Teiserver.Support.Polling, only: [poll_until_some: 1, poll_until_nil: 1]

  @moduletag :tachyon

  @default_user_id "1234"

  test "create a lobby" do
    {:ok, pid, details} =
      mk_start_params([1, 1]) |> Lobby.create()

    p = poll_until_some(fn -> Lobby.lookup(details.id) end)
    assert p == pid
  end

  test "must have a game in db" do
    result =
      mk_start_params([1, 1])
      |> Map.replace!(:game_version, nil)
      |> Lobby.create()

    assert result == {:error, :no_game_version_found}
  end

  test "get default game from db" do
    game = AssetFixtures.create_game(%{name: "test-game", in_matchmaking: true})

    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.replace!(:game_version, nil)
      |> Lobby.create()

    assert details.game_version == game.name
  end

  test "must have engine in db" do
    result =
      mk_start_params([1, 1])
      |> Map.replace!(:engine_version, nil)
      |> Lobby.create()

    assert result == {:error, :no_engine_version_found}
  end

  test "get default engine from db" do
    engine = AssetFixtures.create_engine(%{name: "test-engine", in_matchmaking: true})

    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.replace!(:engine_version, nil)
      |> Lobby.create()

    assert details.engine_version == engine.name
  end

  test "create with defaults" do
    AssetFixtures.create_map(%{
      spring_name: "the map",
      display_name: "the map",
      thumbnail_url: "http://irrelevant.com",
      modoptions: %{
        mapmetadata_startpos: "ImNvdWNvdSIK",
        mapmetadata_startboxes_set: "ImhlbGxvIgo="
      }
    })

    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.put(:map_name, "the map")
      |> Lobby.create()

    assert details.boss_enabled? == false
    assert details.bosses == MapSet.new()

    assert details.game_options == %{
             "mapmetadata_startpos" => "ImNvdWNvdSIK",
             "mapmetadata_startboxes_set" => "ImhlbGxvIgo="
           }
  end

  test "create lobby with game options" do
    {:ok, _pid, details} =
      mk_start_params([1, 1])
      |> Map.put(:game_options, %{"foo" => "bar"})
      |> Lobby.create()

    assert details.game_options == %{"foo" => "bar"}
    {:ok, details2} = LobbyProcess.get_details(details.id)
    assert details2.game_options == %{"foo" => "bar"}
  end

  test "creator is boss when enabled" do
    user_id = AccountFixtures.user_fixture().id

    {:ok, _pid, details} =
      mk_start_params([1, 1], user_id)
      |> Map.put(:boss_enabled?, true)
      |> Lobby.create()

    assert details.boss_enabled? == true
    assert details.bosses == MapSet.new([user_id])
  end

  test "exit when no more players" do
    test_pid = self()

    {:ok, pid} =
      Task.start(fn ->
        {:ok, _pid, details} =
          mk_start_params([1, 1]) |> Lobby.create()

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
      assert {:error, :invalid_lobby} == Lobby.join("nope", mk_player(), self())
    end

    test "as a spectator" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1]) |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      other_user = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, details} = Lobby.join(id, mk_player(other_user), sink_pid)
      assert details.spectators[other_user.id].join_queue_position == nil

      other_user_id = other_user.id

      assert_receive {:lobby, ^id,
                      {:updated, %{spectators: %{^other_user_id => %{join_queue_position: nil}}}}}
    end

    test "is idempotent" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 1]) |> Lobby.create()

      other_user = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, details} = Lobby.join(id, mk_player(other_user), self())
      {:ok, _lobby_pid2, details2} = Lobby.join(id, mk_player(other_user), self())
      assert details == details2
    end

    test "participants get updated events on join" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)

      assert_receive {:lobby, ^id,
                      {:updated, %{spectators: %{^user2_id => %{join_queue_position: nil}}}}}

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:ok, _lobby_pid2, _details2} = Lobby.join(id, mk_player(user2), sink_pid)

      expected_updates = %{spectators: %{user2_id => %{join_queue_position: nil}}}

      assert_receive {:lobby, ^id, {:updated, ^expected_updates}}
    end

    test "lobby full" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      users =
        for _i <- 1..250 do
          user = AccountFixtures.user_fixture()
          {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user), sink_pid)
          user
        end

      # there should be 250 specs and 1 player now, which is the absolute limit
      {:error, :lobby_full} = Lobby.join(id, mk_player(), sink_pid)

      # user already in the lobby are still fine
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(Enum.at(users, 10)), sink_pid)
    end
  end

  describe "joining an ally team" do
    test "must be valid lobby" do
      {:error, :invalid_lobby} = Lobby.join_ally_team("nope", "user", 0)
    end

    test "must be in lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.leave(id, "not here")
    end

    test "must target valid ally team" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2))
      {:error, :invalid_ally_team} = Lobby.join_ally_team(id, user2.id, 2)
    end

    test "ally team must have empty space" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2))
      {:error, :ally_team_full} = Lobby.join_ally_team(id, user2.id, 0)
    end

    test "works" do
      user_id = AccountFixtures.user_fixture().id
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id} = create_details} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      assert %{ready?: false, asset_status: :complete} = create_details.players[user_id]
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _join_details} = Lobby.join(id, mk_player(user2), sink_pid)
      {:ok, details} = Lobby.join_ally_team(id, user2.id, 1)
      assert %{team: {1, _team_number, _position}} = details.players[user2.id]
      assert %{ready?: false, asset_status: :complete} = details.players[user2.id]

      # is idempotent
      {:ok, details2} = Lobby.join_ally_team(id, user2.id, 1)
      assert details == details2
    end

    test "player moving also get updates" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1]) |> Map.put(:creator_pid, sink_pid) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _join_details} = Lobby.join(id, mk_player(user2))
      {:ok, _team_details} = Lobby.join_ally_team(id, user2.id, 1)

      expected = %{
        players: %{user2.id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete}},
        spectators: %{user2.id => nil}
      }

      assert_receive {:lobby, ^id, {:updated, ^expected}}
    end

    test "can change ally team" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _join_details} = Lobby.join(id, mk_player(user2), sink_pid)
      {:ok, details} = Lobby.join_ally_team(id, user2.id, 1)
      assert %{team: {1, _team_number1, _position1}} = details.players[user2.id]

      {:ok, details} = Lobby.join_ally_team(id, user2.id, 0)
      assert %{team: {0, _team_number2, _position2}} = details.players[user2.id]
    end

    test "changing ally team updates" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _join_details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _join_update}}

      {:ok, _details1} = Lobby.join_ally_team(id, user2.id, 1)
      assert_receive {:lobby, ^id, {:updated, update}}
      %{players: %{^user2_id => %{team: {1, 0, 0}}}} = update

      {:ok, _details2} = Lobby.join_ally_team(id, user2.id, 0)
      assert_receive {:lobby, ^id, {:updated, update}}
      %{players: %{^user2_id => %{team: {0, 1, 0}}}} = update
    end

    test "other players are reshuffled" do
      user_id = AccountFixtures.user_fixture().id
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _join_details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive _join_event

      {:ok, details} = Lobby.join_ally_team(id, user2.id, 0)

      expected_update = %{
        players: %{user2.id => %{team: {0, 1, 0}, ready?: false, asset_status: :complete}},
        spectators: %{user2.id => nil}
      }

      assert_receive {:lobby, ^id, {:updated, ^expected_update}}

      assert %{team: {0, _team_number, _position}} = details.players[user2.id]

      # moving from ally team 0 to 1 should reorder "user2" in the first ally team
      {:ok, details} = Lobby.join_ally_team(id, user_id, 1)
      user2_id = user2.id
      %{^user_id => %{team: {1, 0, 0}}, ^user2_id => %{team: {0, 0, 0}}} = details.players
    end
  end

  describe "leaving" do
    test "cannot leave lobby if not in the lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 1]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.leave(id, "not here")
    end

    test "cannot leave lobby if already left" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 1]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), self())
      :ok = Lobby.leave(id, user2.id)
      {:error, :not_in_lobby} = Lobby.leave(id, user2.id)
    end

    test "can leave lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()
      user4 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), self())
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user3), self())
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user4), self())

      {:ok, _details} = Lobby.join_ally_team(id, user3.id, 1)
      {:ok, details} = Lobby.join_ally_team(id, user4.id, 1)

      # user 3 and 4 should be on the same team
      assert details.players[user3.id].team == {1, 0, 0}
      assert details.players[user4.id].team == {1, 1, 0}
      :ok = Lobby.leave(id, user3.id)

      # join again to get the details
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user3), self())
      {:ok, details} = Lobby.join_ally_team(id, user3.id, 1)
      assert details.players[user4.id].team == {1, 0, 0}
      assert details.players[user3.id].team == {1, 1, 0}
    end

    test "can leave lobby and rejoin" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      player = mk_player(user2)
      {:ok, _pid, _details} = Lobby.join(id, player, self())
      :ok = Lobby.leave(id, user2.id)
      {:ok, _pid, _details} = Lobby.join(id, player, self())
    end

    test "leaving lobby send updates to remaining members" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_received {:lobby, ^id, {:updated, _}}

      :ok = Lobby.leave(id, user2.id)
      expected = %{spectators: %{user2.id => nil}}
      assert_received {:lobby, ^id, {:updated, ^expected}}
    end

    test "reshuffling player on leave sends updates" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()
      user4 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user3), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user4), sink_pid)

      assert_received {:lobby, ^id, {:updated, %{}}}
      assert_received {:lobby, ^id, {:updated, %{}}}
      assert_received {:lobby, ^id, {:updated, %{}}}

      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 1)
      {:ok, _details} = Lobby.join_ally_team(id, user3.id, 1)

      assert_received {:lobby, ^id, {:updated, %{}}}
      assert_received {:lobby, ^id, {:updated, %{}}}

      :ok = Lobby.leave(id, user2.id)

      expected = %{
        players: %{
          user2.id => nil,
          user3.id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete}
        }
      }

      assert_received {:lobby, ^id, {:updated, ^expected}}
    end

    test "player pid dying means player is removed from lobby" do
      user_id = AccountFixtures.user_fixture().id
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Map.put(:creator_pid, sink_pid) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), self())
      Process.exit(sink_pid, :kill)

      assert_receive {:lobby, ^id, {:updated, %{players: %{^user_id => nil}}}}
    end

    test "spectator pid dying means is removed from lobby" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, %{}}}

      Process.exit(sink_pid, :kill)

      assert_receive {:lobby, ^id, {:updated, %{spectators: %{^user2_id => nil}}}}
    end

    test "spec leaving removes monitors" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, lobby_pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, %{}}}

      :ok = Lobby.leave(id, user2.id)
      assert_receive {:lobby, ^id, {:updated, %{}}}
      Process.exit(sink_pid, :kill)
      refute_receive _, 30
      assert Process.alive?(lobby_pid)
    end

    test "player leaving removes monitors" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, lobby_pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, %{}}}
      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 1)
      assert_receive {:lobby, ^id, {:updated, %{}}}

      :ok = Lobby.leave(id, user2.id)
      assert_receive {:lobby, ^id, {:updated, %{}}}
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
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.spectate(id, "not in lobby")
    end

    test "works" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.spectate(id, user_id)

      expected = %{
        players: %{user_id => nil},
        spectators: %{user_id => %{join_queue_position: nil}}
      }

      assert_receive {:lobby, ^id, {:updated, ^expected}}
    end

    test "is idempotent" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.spectate(id, user_id)
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.spectate(id, user_id)
      refute_receive _, 30
    end
  end

  describe "join queue" do
    test "with invalid lobby" do
      {:error, :invalid_lobby} = Lobby.join_queue("not-a-lobby", "user1")
    end

    test "not in lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.join_queue(id, "not in lobby")
    end

    test "can immediately join when spot available" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby()
      :ok = Lobby.join_queue(id, u2.id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      u2_id = u2.id
      assert %{players: %{^u2_id => %{team: {1, 0, 0}}}} = updates
    end

    test "doesn't queue if spaces are available" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby()
      u2_id = u2.id
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      {:ok, details} = LobbyProcess.get_details(id)
      assert is_map_key(details.players, u2_id)
      assert %{players: %{^u2_id => %{team: {1, 0, 0}}}} = updates
      :ok = Lobby.join_queue(id, u2_id)
      refute_receive _, 30
    end

    test "player can join the back of the queue" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      %{spectators: %{^u3_id => %{join_queue_position: pos}}} = updates

      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}

      # player 2 is at the back of the queue now
      assert %{spectators: %{^u2_id => %{join_queue_position: pos2}}} = updates
      assert pos2 > pos
      # and player 3 is now playing
      %{spectators: %{^u3_id => nil}, players: %{^u3_id => %{}}} = updates
    end

    test "join wait queue when full" do
      %{id: id, users: [u2, u3, u4 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id, u4_id} = {u2.id, u3.id, u4.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      :ok = Lobby.join_queue(id, u4_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u4_id => %{join_queue_position: 2}}} = updates
    end

    test "can go from join queue to spectator" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      :ok = Lobby.spectate(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: nil}}} = updates
    end

    test "when in queue calling again does nothing" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      # joining the queue again should not change anything
      :ok = Lobby.join_queue(id, u3_id)
      refute_receive _, 30
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.spectators[u3_id].join_queue_position == 1
    end

    test "join team when player become spectator" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      :ok = Lobby.spectate(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}

      assert %{
               spectators: %{^u3_id => nil},
               players: %{^u3_id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete}}
             } = updates
    end

    test "join team when player leaves the lobby" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      :ok = Lobby.leave(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}

      assert %{
               players: %{
                 ^u2_id => nil,
                 ^u3_id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete}
               }
             } = updates
    end

    test "join team when player disappear" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      Process.unlink(u2.pid)
      Process.exit(u2.pid, :kill)
      assert_receive {:lobby, ^id, {:updated, updates}}

      assert %{
               players: %{
                 ^u3_id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete},
                 ^u2_id => nil
               }
             } = updates
    end

    test "spec queue positions works" do
      %{id: id, users: [u2, u3, u4 | _rest]} = setup_full_lobby([1, 1])
      {u2_id, u3_id, u4_id} = {u2.id, u3.id, u4.id}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u3_id => %{join_queue_position: 1}}} = updates

      :ok = Lobby.join_queue(id, u4_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u4_id => %{join_queue_position: 2}}} = updates

      # make sure that user2 rejoining is put at the back of the queue
      :ok = Lobby.leave(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _leave_update}}
      {:ok, _lobby_pid, _details} = Lobby.join(id, u2)
      assert_receive {:lobby, ^id, {:updated, _join_update}}
      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}
      assert %{spectators: %{^u2_id => %{join_queue_position: 3}}} = updates
    end
  end

  describe "bots" do
    test "need valid lobby" do
      {:error, :invalid_lobby} =
        Lobby.add_bot("doesn't exist", 0, "random-user-id", "bot short name")
    end

    test "must be in lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.add_bot(id, "random-user-id", 0, "bot short name")
    end

    test "must specify valid ally team" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:error, :invalid_ally_team} = Lobby.add_bot(id, user_id, 10, "bot short name")
      {:error, :invalid_ally_team} = Lobby.add_bot(id, user_id, -1, "bot short name")
    end

    test "must have space in ally team" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:error, :ally_team_full} = Lobby.add_bot(id, user_id, 0, "bot short name")
    end

    test "add_bot works" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:ok, bot_id} = Lobby.add_bot(id, user_id, 1, "bot short name")

      assert_receive {:lobby, ^id, {:updated, update}}

      %{
        bots: %{
          ^bot_id => %{
            team: {1, 0, 0},
            host_user_id: ^user_id,
            short_name: "bot short name"
          }
        }
      } = update
    end

    test "lobby details has the bots" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:ok, bot_id} =
        Lobby.add_bot(id, user_id, 1, "bot short name",
          name: "bot name",
          version: "version",
          options: %{
            "option1" => "val1"
          }
        )

      {:ok, details} = LobbyProcess.get_details(id)

      refute is_map_key(details.players, bot_id)

      %{
        host_user_id: ^user_id,
        team: {1, 0, 0},
        short_name: "bot short name",
        name: "bot name",
        version: "version",
        options: %{"option1" => "val1"}
      } = details.bots[bot_id]
    end

    test "bots correctly put in teams" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([3, 3], user_id) |> Lobby.create()

      {:ok, bot_id1} = Lobby.add_bot(id, user_id, 0, "bot short name")
      assert_receive {:lobby, ^id, {:updated, update}}
      %{bots: %{^bot_id1 => %{team: {0, 1, 0}}}} = update

      {:ok, bot_id2} = Lobby.add_bot(id, user_id, 0, "bot short name")
      assert_receive {:lobby, ^id, {:updated, update}}
      %{bots: %{^bot_id2 => %{team: {0, 2, 0}}}} = update
    end

    test "bots are taken into account for team capacity" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:ok, _bot_id} = Lobby.add_bot(id, user_id, 1, "bot short name")
      {:error, :ally_team_full} = Lobby.add_bot(id, user_id, 1, "bot short name")
    end

    test "creator leaving also removes bots" do
      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])

      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _join_update}}

      {:ok, bot_id1} = Lobby.add_bot(id, user2_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _bot1_update}}

      {:ok, bot_id2} = Lobby.add_bot(id, user2_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _bot2_update}}

      :ok = Lobby.leave(id, user2_id)
      assert_receive {:lobby, ^id, {:updated, update}}

      %{
        bots: %{^bot_id1 => nil, ^bot_id2 => nil},
        spectators: %{^user2_id => nil}
      } = update
    end

    test "bot leaving because spec host left allow join queue to get in" do
      %{id: id, users: [u2, u3, u4 | _rest]} = setup_full_lobby()
      {u2_id, u3_id, u4_id} = {u2.id, u3.id, u4.id}

      # fill the lobby with bots
      {:ok, bot_id1} = Lobby.add_bot(id, u2_id, 0, "bot")
      {:ok, bot_id2} = Lobby.add_bot(id, u2_id, 1, "bot")
      {:ok, bot_id3} = Lobby.add_bot(id, u2_id, 1, "bot")

      # also fill a bit the join queue
      :ok = Lobby.join_queue(id, u3_id)
      :ok = Lobby.join_queue(id, u4_id)

      for _i <- 1..5, do: assert_receive({:lobby, ^id, {:updated, _update}})

      # player 2 leaving should make all the bots leave and the space should be
      # taken up by the players in the join queue
      :ok = Lobby.leave(id, u2_id)

      assert_receive({:lobby, ^id, {:updated, update}})

      # bots should be gone
      %{bots: %{^bot_id1 => nil, ^bot_id2 => nil, ^bot_id3 => nil}} = update

      # players in join queue should be in team now
      assert update.players[u3_id].team == {1, 0, 0}
      assert update.players[u4_id].team == {0, 1, 0}
      %{spectators: %{^u2_id => nil, ^u3_id => nil, ^u4_id => nil}} = update
    end

    test "correct id required to remove bot" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :invalid_bot_id} = Lobby.remove_bot(id, @default_user_id, "lolnope")
    end

    test "remove_bot works" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:ok, bot_id} = Lobby.add_bot(id, user_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.remove_bot(id, user_id, bot_id)
      assert_receive {:lobby, ^id, {:updated, update}}
      %{bots: %{^bot_id => nil}} = update
    end

    # TODO: this test raises a logging error with lobby log
    # trying to log a user id that is actually a bot
    test "removing a bot reshuffle the teams" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:ok, bot_id1} = Lobby.add_bot(id, user_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _}}
      {:ok, bot_id2} = Lobby.add_bot(id, user_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.remove_bot(id, user_id, bot_id1)

      assert_receive {:lobby, ^id, {:updated, update}}
      %{bots: %{^bot_id1 => nil, ^bot_id2 => %{team: {1, 0, 0}}}} = update
    end

    test "removing bot allow specs in join queue to get the spot" do
      # Setup
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:ok, bot_id} = Lobby.add_bot(id, user_id, 1, "bot short name")
      assert_receive {:lobby, ^id, {:updated, _}}

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _join_update}}

      :ok = Lobby.join_queue(id, user2_id)
      assert_receive {:lobby, ^id, {:updated, update}}
      %{spectators: %{^user2_id => %{join_queue_position: 1}}} = update

      # Act
      :ok = Lobby.remove_bot(id, user_id, bot_id)

      # Assert
      assert_receive {:lobby, ^id, {:updated, update}}
      # bot is gone
      %{bots: %{^bot_id => nil}} = update
      # and player took its place
      %{spectators: %{^user2_id => nil}, players: %{^user2_id => %{team: _team}}} =
        update
    end

    test "player in join queue with bot leaves" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby([1, 1])
      u2_id = u2.id
      {:ok, bot_id} = Lobby.add_bot(id, u2_id, 1, "bot")
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.join_queue(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.leave(id, u2_id)
      assert_receive {:lobby, ^id, {:updated, updates}}

      assert %{spectators: %{u2_id => nil}, bots: %{bot_id => nil}} == updates
    end

    test "update needs correct id" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :invalid_bot_id} = Lobby.update_bot(id, %{id: "lolnope"})
    end

    test "can update some properties" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:ok, bot_id} = Lobby.add_bot(id, user_id, 1, "bot")
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.update_bot(id, %{id: bot_id, name: "botv2", short_name: "short v2"})

      # we got the events
      assert_receive {:lobby, ^id, {:updated, update}}
      %{bots: %{^bot_id => %{name: "botv2", short_name: "short v2"}}} = update

      # and the details are also correct
      {:ok, details} = LobbyProcess.get_details(id)
      %{name: "botv2", short_name: "short v2"} = details.bots[bot_id]
    end
  end

  describe "updates" do
    test "need valid lobby" do
      user_id = AccountFixtures.user_fixture().id

      assert {:error, :invalid_lobby} ==
               Lobby.update_properties("lolnope", user_id, %{name: "nope"})
    end

    test "only supported properties" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:error, _reason} =
        Lobby.update_properties(id, user_id, %{definitely_not_supported: "nope"})
    end

    test "name work" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{name: "new name"})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.name == "new name"
      assert_receive {:lobby, ^id, {:updated, %{name: "new name"}}}
    end

    test "name must be valid" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %{id: id}} =
        mk_start_params([2, 1], user_id) |> Lobby.create()

      {:error, _error} = Lobby.update_properties(id, user_id, %{name: "="})
    end

    test "map name" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{map_name: "new map"})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.map_name == "new map"
      assert_receive {:lobby, ^id, {:updated, %{map_name: "new map"}}}
    end

    test "only players can change the map" do
      user2 = AccountFixtures.user_fixture()
      %{id: id} = setup_full_lobby([1, 1])
      {:error, _reason} = Lobby.update_properties(id, user2.id, %{map_name: "new map"})
    end
  end

  describe "voting" do
    test "changing map with 2 players requires a vote" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      {:ok, original_details} = LobbyProcess.get_details(id)

      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.map_name == original_details.map_name
      vote = details.current_vote
      assert vote != assert(match?(%{action: _, id: "vote-1"}, vote))
      assert vote.voters[creator_id] == :yes, "initiator is always yes"
      assert vote.voters[u2.id] == :pending, "other voters are pending"
      assert vote.action == {:change_map, "new map"}

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote_update}}}
      assert vote_update.id == vote.id
      assert %{majority: 0.501, quorum: 2} = vote_update
    end

    test "changing a second time does nothing" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby([1, 1])
      u2_id = u2.id
      :ok = Lobby.join_queue(id, u2_id)
      :ok = Lobby.update_properties(id, u2_id, %{map_name: "new map"})

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      assert vote != assert(match?(%{action: _, id: "vote-1"}, vote))

      :ok = Lobby.update_properties(id, u2_id, %{map_name: "new map"})
    end

    test "vote timeout with no votes" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      u2_id = u2.id
      :ok = Lobby.join_queue(id, u2_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      LobbyProcess.trigger_vote_timeout(id, vote.id)
      assert_receive {:lobby, ^id, {:updated, %{current_vote: nil}}}
      vote_id = vote.id
      assert_receive {:lobby, ^id, {:vote_ended, ^vote_id, :timeout}}
    end

    test "vote timeout with cast votes" do
      %{id: id, users: [u2, u3, u4 | _rest], creator_id: creator_id} = setup_full_lobby([2, 2])
      for user_id <- [u2.id, u3.id, u4.id], do: :ok = Lobby.join_queue(id, user_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      vote_id = vote.id

      # We have 4 players, 3 votes needed for quorum
      assert vote.quorum == 3
      assert vote.majority == 0.501

      # 2 yes (vote initiator is voting yes by default), 1 no vote
      # the result is uncertain,
      # the vote continues because the forht player can change the outcome
      :ok = Lobby.vote_submit(id, u2.id, {vote_id, :yes})
      :ok = Lobby.vote_submit(id, u3.id, {vote_id, :no})

      LobbyProcess.trigger_vote_timeout(id, vote_id)

      # Vote reached timeout and since we have quorum votes the result is valid
      # From the non abstaining cast votes we have 2/3 yes votes
      # which is higher than the 50.1% majority needed, the vote passed
      assert_receive {:lobby, ^id, {:vote_ended, ^vote_id, :passed}}

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.map_name == "new map"
    end

    test "vote ends if remaining votes can't change outcome" do
      %{id: id, users: [u2, u3, u4 | _rest], creator_id: creator_id} = setup_full_lobby([2, 2])
      for user_id <- [u2.id, u3.id, u4.id], do: :ok = Lobby.join_queue(id, user_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      vote_id = vote.id

      # We have 4 players, 3 votes needed for quorum
      assert vote.quorum == 3
      assert vote.majority == 0.501

      # 1 yes (vote initiator is voting yes by default), 2 no votes
      :ok = Lobby.vote_submit(id, u2.id, {vote_id, :no})
      :ok = Lobby.vote_submit(id, u3.id, {vote_id, :no})

      # There is no way to change the outcome by the pending votes
      # so the vote will end immediately to save time
      # From the non abstaining cast votes we have 1/3 yes votes
      # which is less than the 50.1% majority required for the vote to pass
      # therefore the vote failed
      assert_receive {:lobby, ^id, {:vote_ended, ^vote_id, :failed}}

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.map_name != "new map"
    end

    test "vote ends early if everyone voted" do
      %{id: id, users: [u2, u3, u4 | _rest], creator_id: creator_id} = setup_full_lobby([2, 2])
      for user_id <- [u2.id, u3.id, u4.id], do: :ok = Lobby.join_queue(id, user_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      vote_id = vote.id

      # We have 4 players, 3 votes needed for quorum
      assert vote.quorum == 3
      assert vote.majority == 0.501

      # 1 yes (vote initiator is voting yes by default), 2 no, 2 abstain votes
      :ok = Lobby.vote_submit(id, creator_id, {vote_id, :abstain})
      :ok = Lobby.vote_submit(id, u2.id, {vote_id, :abstain})
      :ok = Lobby.vote_submit(id, u3.id, {vote_id, :abstain})
      :ok = Lobby.vote_submit(id, u4.id, {vote_id, :abstain})

      # Everyone voted so the vote is ended early to save time
      # From the non abstaining cast votes we have 0/0 yes votes
      # which is less than the 50.1% majority required for the vote pass
      # therefore the vote failed
      assert_receive {:lobby, ^id, {:vote_ended, ^vote_id, :failed}}
    end

    test "voter disconnect is the same as leaving (abstain)" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      u2_id = u2.id
      :ok = Lobby.join_queue(id, u2_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      Process.unlink(u2.pid)
      Process.exit(u2.pid, :kill)

      # 1 yes vote from the vote initiator and an abstain from the leaver
      # meets quorum (everyone voted)
      # From the non abstaining cast votes we have 1/1 yes votes
      # which is more than the 50.1% majority required for the vote to pass
      assert_receive {:lobby, ^id, {:updated, %{current_vote: nil}}}
      assert_receive {:lobby, ^id, {:vote_ended, vote_id, result}}
      assert vote_id == vote.id
      assert result == :passed
    end

    test "vote timeout is bound to a current vote" do
      {:ok, _pid, %{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      LobbyProcess.trigger_vote_timeout(id, "definitely-not-a-vote-id")
      refute_receive {:lobby, ^id, {:updated, %{current_vote: nil}}}, 30
    end

    test "must specify correct lobby id to vote" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      {:error, :invalid_lobby} = Lobby.vote_submit("not-a-lobby-id", "2", {vote.id, :yes})
    end

    test "must specify correct vote_id to vote" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: _vote}}}

      {:error, :invalid_vote} = Lobby.vote_submit(id, u2.id, {"invalid-vote-id", :yes})
    end

    test "must be one of the allowed voters" do
      %{id: id, users: [u2, u3 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      {:error, :invalid_vote} = Lobby.vote_submit(id, u3.id, {vote.id, :yes})
    end

    test "members get updates when vote is cast" do
      %{id: id, users: [u2, u3, u4 | _rest], creator_id: creator_id} = setup_full_lobby([2, 2])
      for user_id <- [u2.id, u3.id, u4.id], do: :ok = Lobby.join_queue(id, user_id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      :ok = Lobby.vote_submit(id, creator_id, {vote.id, :no})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: updated_vote}}}
      assert updated_vote.voters[creator_id] == :no
    end

    test "can change map when vote passes" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      :ok = Lobby.vote_submit(id, u2.id, {vote.id, :yes})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: nil, map_name: "new map"}}}
      assert_receive {:lobby, ^id, {:vote_ended, vote_id, result}}
      assert vote_id == vote.id
      assert result == :passed
    end

    test "history to track votes" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)

      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      :ok = Lobby.vote_submit(id, u2.id, {vote.id, :yes})
      vote_id = vote.id

      assert_receive {:lobby, ^id, {:updated, %{vote_history: %{^vote_id => vote1}}}}

      assert %{vote: {:change_map, "new map"}, outcome: :passed} = vote1

      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map2"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      :ok = Lobby.vote_submit(id, u2.id, {vote.id, :no})
      vote_id2 = vote.id

      assert_receive {:lobby, ^id, {:updated, %{vote_history: %{^vote_id2 => vote2}}}}

      %{vote: {:change_map, "new map2"}, outcome: :failed} = vote2

      # and lobby details hold the entire history
      {:ok, details} = LobbyProcess.get_details(id)
      assert map_size(details.vote_history) == 2
      assert vote_id < vote_id2
      record1 = %LT.VoteDetails{} = details.vote_history[vote_id]
      record2 = %LT.VoteDetails{} = details.vote_history[vote_id2]
      assert record1.outcome == :passed
      assert record1.vote == {:change_map, "new map"}
      assert record2.outcome == :failed
      assert record2.vote == {:change_map, "new map2"}
    end

    test "map stays when vote fails" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}

      :ok = Lobby.vote_submit(id, u2.id, {vote.id, :no})
      assert_receive {:lobby, ^id, {:updated, %{current_vote: nil}}}
      assert_receive {:lobby, ^id, {:vote_ended, vote_id, result}}
      assert vote_id == vote.id
      assert result == :failed
    end

    test "cannot change map when vote already pending" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      :ok = Lobby.join_queue(id, u2.id)
      :ok = Lobby.update_properties(id, creator_id, %{map_name: "new map"})
      assert_receive {:lobby, ^id, {:updated, %{players: %{}}}}
      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      assert match?(%{action: _, id: "vote-1"}, vote)

      {:error, _reason} =
        Lobby.update_properties(id, creator_id, %{map_name: "different map"})
    end

    test "only bosses can change map" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby([1, 1], boss_enabled?: true)
      :ok = Lobby.join_queue(id, u2.id)
      {:error, err} = Lobby.update_properties(id, u2.id, %{map_name: "new map"})
      assert err =~ "boss"
    end
  end

  describe "boss manipulation" do
    test "must be in lobby" do
      user_id = AccountFixtures.user_fixture().id
      user2 = AccountFixtures.user_fixture()
      {:error, :invalid_lobby} = Lobby.appoint_boss("not-a-lobby-id", user_id, user2.id)
    end

    test "appointee must be in lobby" do
      %{id: id, creator_id: creator_id} = setup_full_lobby([1, 1])
      {:error, :not_in_lobby} = Lobby.appoint_boss(id, creator_id, "invalid-id")
    end

    test "bosses must be enabled" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: false)

      {:error, :no_boss_allowed} = Lobby.appoint_boss(id, creator_id, u2.id)
    end

    test "user must be a boss" do
      %{id: id, users: [u2, u3 | _rest]} = setup_full_lobby([1, 1], boss_enabled?: true)
      {:error, :not_a_boss} = Lobby.appoint_boss(id, u2.id, u3.id)
    end

    test "can appoint boss" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data == %{bosses: %{u2.id => %{}}}

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.bosses == MapSet.new([creator_id, u2.id])
    end

    test "appointing existing boss in no-op" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data == %{bosses: %{u2.id => %{}}}

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      refute_receive _, 30
    end

    test "unboss - invalid lobby" do
      {:error, :invalid_lobby} = Lobby.unboss("not-a-lobby-id", @default_user_id, "2")
    end

    test "unboss - must be in lobby" do
      %{id: id, creator_id: creator_id} = setup_full_lobby([1, 1], boss_enabled?: true)
      {:error, :not_in_lobby} = Lobby.unboss(id, "not-in-lobby", creator_id)
    end

    test "unboss - no op if target not boss" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.unboss(id, creator_id, u2.id)
      refute_receive _, 30
    end

    test "unboss works" do
      %{id: id, creator_id: creator_id} = setup_full_lobby([1, 1], boss_enabled?: true)
      :ok = Lobby.unboss(id, creator_id, creator_id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data == %{bosses: %{creator_id => nil}}
    end

    test "can appoint boss when no boss" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.unboss(id, creator_id, creator_id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data == %{bosses: %{creator_id => nil}}

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data == %{bosses: %{u2.id => %{}}}
    end

    test "appoint boss triggers vote for players" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.unboss(id, creator_id, creator_id)
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.join_queue(id, u2.id)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      assert_receive {:lobby, ^id, {:updated, data}}

      u2_id = u2.id

      %{action: {:appoint_boss, u2_id}, voters: %{^creator_id => :yes, ^u2_id => :pending}} =
        data.current_vote

      :ok = Lobby.vote_submit(id, u2_id, {data.current_vote.id, :yes})
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data.bosses == %{u2_id => %{}}
    end

    test "leaving lobby unboss" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} =
        setup_full_lobby([1, 1], boss_enabled?: true)

      :ok = Lobby.appoint_boss(id, creator_id, u2.id)
      assert_receive {:lobby, ^id, {:updated, _data}}
      :ok = Lobby.leave(id, u2.id)
      assert_receive {:lobby, ^id, {:updated, data}}
      assert data.bosses == %{u2.id => nil}
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.bosses == MapSet.new([creator_id])
    end
  end

  describe "update ally team" do
    test "work" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      new_ally_team_config = mk_start_params([1, 1]).ally_team_config

      :ok =
        Lobby.update_properties(id, user_id, %{ally_team_config: new_ally_team_config})

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.ally_team_config == new_ally_team_config
      assert_receive {:lobby, ^id, {:updated, %{ally_team_config: patch_config}}}

      assert patch_config == [
               %{
                 max_teams: 1,
                 start_box: %{top: 0, left: 0, bottom: 1, right: 0.2},
                 teams: [%{max_players: 1}, nil]
               },
               %{
                 max_teams: 1,
                 start_box: %{top: 0, left: 0, bottom: 1, right: 0.2},
                 teams: [%{max_players: 1}, nil]
               }
             ]
    end

    test "teams must not be empty" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:error, _message} =
        Lobby.update_properties(id, user_id, %{ally_team_config: %{teams: []}})
    end

    test "ally team config diff with less ally team teams" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1, 1], user_id) |> Lobby.create()

      new_ally_team_config = mk_start_params([1, 1]).ally_team_config

      :ok =
        Lobby.update_properties(id, user_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, %{ally_team_config: patch_config}}}
      # deleted ally team shows as nil
      [_ally_team1, _ally_team2, nil] = patch_config
    end

    test "ally team config diff with less teams" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([3], user_id) |> Lobby.create()

      new_ally_team_config = mk_start_params([2]).ally_team_config

      :ok =
        Lobby.update_properties(id, user_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, %{ally_team_config: patch_config}}}
      # deleted team shows as nil
      [%{max_teams: 2, teams: [_team1, _team2, nil]}] = patch_config
    end

    test "put join queue in newly created spots" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1])
      u2_id = u2.id
      :ok = Lobby.join_queue(id, u2_id)

      assert_receive {:lobby, ^id,
                      {:updated, %{spectators: %{^u2_id => %{join_queue_position: _}}}}}

      new_ally_team_config = mk_start_params([1, 1]).ally_team_config

      :ok =
        Lobby.update_properties(id, creator_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id,
                      {:updated,
                       %{
                         players: %{
                           ^u2_id => %{team: {1, 0, 0}, ready?: false, asset_status: :complete}
                         }
                       }}}
    end

    test "put extra players in join queue" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      u2_id = u2.id
      {:ok, _details} = Lobby.join_ally_team(id, u2_id, 1)
      assert_receive {:lobby, ^id, {:updated, _team_update}}

      new_ally_team_config = mk_start_params([1]).ally_team_config

      :ok =
        Lobby.update_properties(id, creator_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, update}}
      %{players: %{^u2_id => nil}, spectators: %{^u2_id => %{join_queue_position: pos}}} = update
      refute is_nil(pos), "player kicked out of team is in the join queue"
    end

    test "extra players and bots" do
      %{id: id, users: [u2 | _rest]} = setup_full_lobby([1, 3])
      u2_id = u2.id
      {:ok, _bot1} = Lobby.add_bot(id, u2_id, 1, "bot 1")
      {:ok, bot2} = Lobby.add_bot(id, u2_id, 1, "bot 2")
      assert_receive {:lobby, ^id, {:updated, _}}
      assert_receive {:lobby, ^id, {:updated, _}}

      {:ok, _details} = Lobby.join_ally_team(id, u2_id, 1)
      assert_receive {:lobby, ^id, {:updated, _team_update}}

      new_ally_team_config = mk_start_params([1, 1]).ally_team_config
      :ok = Lobby.update_properties(id, u2_id, %{ally_team_config: new_ally_team_config})

      # check that the bot is removed from the lobby, but the player is put in the join queue
      assert_receive {:lobby, ^id, {:updated, update}}

      %{
        bots: %{^bot2 => nil},
        players: %{^u2_id => nil},
        spectators: %{^u2_id => %{join_queue_position: _position}}
      } =
        update

      refute is_map_key(update.spectators, bot2)
    end

    test "can change player's teams when there is space" do
      %{id: id, users: [u2 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      u2_id = u2.id
      {:ok, _details} = Lobby.join_ally_team(id, u2_id, 1)
      assert_receive {:lobby, ^id, {:updated, _team_update}}

      new_ally_team_config = mk_start_params([2]).ally_team_config

      :ok =
        Lobby.update_properties(id, creator_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, update}}
      %{players: %{^u2_id => %{team: {0, 1, 0}}}} = update
      refute is_map_key(update, :spectators), "no spec was moved #{inspect(update)}"
    end

    test "with moved and excess players" do
      %{id: id, users: [u2, u3 | _rest], creator_id: creator_id} = setup_full_lobby([2, 2])
      {u2_id, u3_id} = {u2.id, u3.id}
      {:ok, _details1} = Lobby.join_ally_team(id, u2_id, 1)
      assert_receive {:lobby, ^id, {:updated, _team_update1}}
      {:ok, _details2} = Lobby.join_ally_team(id, u3_id, 1)
      assert_receive {:lobby, ^id, {:updated, _team_update2}}

      new_ally_team_config = mk_start_params([2]).ally_team_config

      :ok =
        Lobby.update_properties(id, creator_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, update}}

      %{
        players: %{^u2_id => %{team: {0, 1, 0}}, ^u3_id => nil},
        spectators: %{^u3_id => %{join_queue_position: 1}}
      } = update
    end

    test "ejected players go at the beginning of the join queue" do
      %{id: id, users: [u2, u3 | _rest], creator_id: creator_id} = setup_full_lobby([1, 1])
      {u2_id, u3_id} = {u2.id, u3.id}
      {:ok, _details} = Lobby.join_ally_team(id, u2_id, 1)
      assert_receive {:lobby, ^id, {:updated, _}}
      :ok = Lobby.join_queue(id, u3_id)
      assert_receive {:lobby, ^id, {:updated, _}}

      new_ally_team_config = mk_start_params([1]).ally_team_config

      :ok =
        Lobby.update_properties(id, creator_id, %{ally_team_config: new_ally_team_config})

      assert_receive {:lobby, ^id, {:updated, update}}

      %{
        players: %{^u2_id => nil},
        spectators: %{^u2_id => %{join_queue_position: pos}}
      } = update

      refute is_nil(pos), "player is now in join queue"
    end
  end

  describe "update player status" do
    test "must be valid lobby" do
      {:error, :invalid_lobby} = Lobby.update_client_status("nolobby", "user1", %{ready?: true})
    end

    test "must be in lobby" do
      user_id = AccountFixtures.user_fixture().id
      user2 = AccountFixtures.user_fixture()

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.update_client_status(id, user2.id, %{ready?: true})
    end

    test "can update properties one by one" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_client_status(id, user_id, %{ready?: true})
      expected = %{players: %{user_id => %{ready?: true}}}
      assert_receive {:lobby, ^id, {:updated, ^expected}}

      :ok = Lobby.update_client_status(id, user_id, %{asset_status: :downloading})
      expected = %{players: %{user_id => %{asset_status: :downloading}}}
      assert_receive {:lobby, ^id, {:updated, ^expected}}
    end

    test "can update multiple properties at once" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok =
        Lobby.update_client_status(id, user_id, %{
          ready?: true,
          asset_status: :downloading
        })

      expected = %{players: %{user_id => %{ready?: true, asset_status: :downloading}}}
      assert_receive {:lobby, ^id, {:updated, ^expected}}
    end

    # in the future we may want to avoid sending events if there is no changes
    # it would cost a bit more cpu to potentially save a few messages, but this
    # could also be handled by client. For now, keep implementation simple
    # and always process the request
    test "send event if no changes" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_client_status(id, user_id, %{ready?: false})
      expected = %{players: %{user_id => %{ready?: false}}}
      assert_receive {:lobby, ^id, {:updated, ^expected}}, 30
    end

    test "only player can update status" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1], user_id) |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)

      {:error, :not_a_player} = Lobby.update_client_status(id, user2.id, %{ready?: true})
    end
  end

  describe "update game options" do
    test "must be in lobby" do
      user_id = AccountFixtures.user_fixture().id
      user2 = AccountFixtures.user_fixture()

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:error, :not_in_lobby} =
        Lobby.update_properties(id, user2.id, %{game_options: %{"foo" => "bar"}})
    end

    test "can add an option" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{game_options: %{"foo" => "bar"}})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.game_options == %{"foo" => "bar"}
      assert_receive {:lobby, ^id, {:updated, %{game_options: %{"foo" => "bar"}}}}
    end

    test "can update option" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:game_options, %{"foo" => "bar"})
        |> Lobby.create()

      :ok =
        Lobby.update_properties(id, user_id, %{game_options: %{"foo" => "another bar"}})

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.game_options == %{"foo" => "another bar"}
      assert_receive {:lobby, ^id, {:updated, %{game_options: %{"foo" => "another bar"}}}}
    end

    test "can remove an option" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:game_options, %{"foo" => "bar"})
        |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{game_options: %{"foo" => nil}})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.game_options == %{}
      assert_receive {:lobby, ^id, {:updated, %{game_options: %{"foo" => nil}}}}
    end

    test "can add remove and update in one request" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:game_options, %{"foo" => "bar", "ranked" => "true"})
        |> Lobby.create()

      :ok =
        Lobby.update_properties(id, user_id, %{
          game_options: %{"foo" => nil, "ranked" => "false", "blah" => "qux"}
        })

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.game_options == %{"ranked" => "false", "blah" => "qux"}

      assert_receive {:lobby, ^id,
                      {:updated,
                       %{game_options: %{"foo" => nil, "ranked" => "false", "blah" => "qux"}}}}
    end

    test "changing map also set polystartboxes" do
      AssetFixtures.create_map(%{
        spring_name: "new map",
        display_name: "new map",
        thumbnail_url: "http://irrelevant.com",
        modoptions: %{
          mapmetadata_startpos: "ImNvdWNvdSIK",
          mapmetadata_startboxes_set: "ImhlbGxvIgo="
        }
      })

      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{map_name: "new map"})

      assert_receive {:lobby, ^id,
                      {:updated,
                       %{
                         map_name: "new map",
                         game_options: %{
                           "mapmetadata_startpos" => "ImNvdWNvdSIK",
                           "mapmetadata_startboxes_set" => "ImhlbGxvIgo="
                         }
                       }}}
    end
  end

  describe "update tags" do
    test "create with initial tags" do
      {:ok, _pid, details} =
        mk_start_params([2, 2])
        |> Map.put(:tags, %{"competitive" => %{}})
        |> Lobby.create()

      assert details.tags == %{"competitive" => %{}}
      {:ok, details2} = LobbyProcess.get_details(details.id)
      assert details2.tags == %{"competitive" => %{}}
    end

    test "defaults to empty tags" do
      {:ok, _pid, details} = mk_start_params([2, 2]) |> Lobby.create()
      assert details.tags == %{}
    end

    test "can add a tag" do
      user_id = AccountFixtures.user_fixture().id
      {:ok, _pid, %LT.Details{id: id}} = mk_start_params([2, 2], user_id) |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{tags: %{"competitive" => %{}}})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.tags == %{"competitive" => %{}}
      assert_receive {:lobby, ^id, {:updated, %{tags: %{"competitive" => %{}}}}}
    end

    test "can remove a tag" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:tags, %{"competitive" => %{}, "no_rush" => %{}})
        |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{tags: %{"competitive" => nil}})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.tags == %{"no_rush" => %{}}
      assert_receive {:lobby, ^id, {:updated, %{tags: %{"competitive" => nil}}}}
    end

    test "existing tags survive partial update" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:tags, %{"competitive" => %{}, "no_rush" => %{}})
        |> Lobby.create()

      :ok = Lobby.update_properties(id, user_id, %{tags: %{"ranked" => %{}}})
      {:ok, details} = LobbyProcess.get_details(id)
      assert details.tags == %{"competitive" => %{}, "no_rush" => %{}, "ranked" => %{}}
    end

    test "can add remove and update in one request" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:tags, %{"competitive" => %{}, "no_rush" => %{}})
        |> Lobby.create()

      :ok =
        Lobby.update_properties(id, user_id, %{
          tags: %{"competitive" => nil, "ranked" => %{}}
        })

      {:ok, details} = LobbyProcess.get_details(id)
      assert details.tags == %{"no_rush" => %{}, "ranked" => %{}}

      assert_receive {:lobby, ^id, {:updated, %{tags: %{"competitive" => nil, "ranked" => %{}}}}}
    end
  end

  describe "kickban" do
    test "banned player cannot rejoin lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _}}
      ban_until = DateTime.add(DateTime.utc_now(), 3600, :second)
      :ok = Lobby.kickban(id, user_id, user2.id, ban_until)

      {:error, :banned, _ban_until} = Lobby.join(id, mk_player(user2), sink_pid)
    end

    test "kicked spectator can rejoin lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
      SessionRegistry.register(user2.id, nil)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.kickban(id, user_id, user2.id)
      assert_receive {:"$gen_cast", {:lobby, {:left, ^id, :kicked}}}

      {:ok, details} = LobbyProcess.get_details(id)
      refute is_map_key(details.spectators, user2.id)

      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
    end

    test "kickban remaining members receive updated when player is kicked" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _}}

      :ok = Lobby.kickban(id, user_id, user2.id)
      user2_id = user2.id
      assert_receive {:lobby, ^id, {:updated, %{spectators: %{^user2_id => nil}}}}
    end

    test "kickban kicked player receives only left event, not updated" do
      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])

      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Map.put(:creator_pid, sink_pid)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
      SessionRegistry.register(user2.id, nil)

      :ok = Lobby.kickban(id, user_id, user2.id)

      assert_receive {:"$gen_cast", {:lobby, {:left, ^id, :kicked}}}
      refute_receive {:lobby, ^id, {:updated, _}}, 30
    end

    test "player can rejoin lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
      SessionRegistry.register(user2.id, nil)
      assert_receive {:lobby, ^id, {:updated, _}}

      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 0)

      :ok = Lobby.kickban(id, user_id, user2.id)
      assert_receive {:"$gen_cast", {:lobby, {:left, ^id, :kicked}}}

      {:ok, details} = LobbyProcess.get_details(id)
      refute is_map_key(details.players, user2.id)

      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
    end

    test "fails when caller is not in lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
      assert_receive {:lobby, ^id, {:updated, _}}

      {:error, :not_in_lobby} = Lobby.kickban(id, "not-in-lobby", user2.id)
    end

    test "fails when target is not in lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:error, :invalid_request} = Lobby.kickban(id, user_id, user2.id)
    end

    test "kickban triggers vote when boss is not enabled" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 0)
      drain_msg_queue()

      :ok = Lobby.kickban(id, user_id, user2.id)

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      assert vote.action == {:kickban, user2.id, nil}
    end

    test "fails when caller is not a boss" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), self())
      assert_receive {:lobby, ^id, {:updated, _}}

      {:error, :not_boss} = Lobby.kickban(id, user2.id, user_id)
    end

    test "kickban starts a vote when no boss and multiple players" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([3, 3], user_id)
        |> Lobby.create()

      {:ok, sink_pid2} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, sink_pid3} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid2)
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user3), sink_pid3)
      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 0)
      {:ok, _details} = Lobby.join_ally_team(id, user3.id, 0)
      drain_msg_queue()

      :ok = Lobby.kickban(id, user_id, user2.id)

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      assert vote.action == {:kickban, user2.id, nil}
      assert vote.voters[user_id] == :yes
      assert vote.voters[user2.id] == :pending
      assert vote.voters[user3.id] == :pending

      :ok = Lobby.vote_submit(id, user3.id, {vote.id, :yes})

      user2_id = user2.id
      assert_receive {:lobby, ^id, {:updated, %{players: %{^user2_id => nil}, current_vote: nil}}}
      assert_receive {:lobby, ^id, {:vote_ended, _vote_id, :passed}}

      {:ok, details} = LobbyProcess.get_details(id)
      refute is_map_key(details.players, user2.id)
      refute is_map_key(details.spectators, user2.id)
    end

    test "kickban vote is cancelled when target leaves" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([3, 3], user_id)
        |> Lobby.create()

      {:ok, sink_pid2} = Task.start_link(:timer, :sleep, [:infinity])
      {:ok, sink_pid3} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      user3 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid2)
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user3), sink_pid3)
      {:ok, _details} = Lobby.join_ally_team(id, user2.id, 0)
      {:ok, _details} = Lobby.join_ally_team(id, user3.id, 0)
      drain_msg_queue()

      :ok = Lobby.kickban(id, user_id, user2.id)

      assert_receive {:lobby, ^id, {:updated, %{current_vote: vote}}}
      assert vote.action == {:kickban, user2.id, nil}

      :ok = Lobby.leave(id, user2.id)

      user2_id = user2.id

      assert_receive {
        :lobby,
        ^id,
        {:updated, %{current_vote: nil, players: %{^user2_id => nil}}}
      }

      assert_receive {:lobby, ^id, {:vote_ended, _vote_id, :cancelled}}
    end

    test "expired ban allows rejoin lobby" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id)
        |> Map.put(:boss_enabled?, true)
        |> Lobby.create()

      {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
      assert_receive {:lobby, ^id, {:updated, _}}

      ban_until = DateTime.add(DateTime.utc_now(), 30, :millisecond)
      :ok = Lobby.kickban(id, user_id, user2.id, ban_until)

      {:error, :banned, _ban_until} = Lobby.join(id, mk_player(user2), sink_pid)

      Process.sleep(50)

      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2), sink_pid)
    end
  end

  # note: [test lobby battle]
  # these tests are a bit anemic because they also require a connected autohost
  # and it's a lot of setup. There are some end to end tests in the
  # teiserver_web/tachyon/lobby_test.exs file
  # though this section could also be expanded
  describe "start battle" do
    test "lobby must be valid" do
      {:error, :invalid_lobby} = Lobby.start_battle("nolobby", "user1")
    end

    test "must be in lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.start_battle(id, "not in lobby")
    end
  end

  # see note: [test lobby battle]
  describe "join battle" do
    test "lobby must be valid" do
      {:error, :invalid_lobby} = Lobby.join_battle("nolobby", "user1")
    end

    test "must be in lobby" do
      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2]) |> Lobby.create()

      {:error, :not_in_lobby} = Lobby.join_battle(id, "not in lobby")
    end
  end

  describe "start script" do
    test "with 1 player" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      start_script = LobbyProcess.get_start_script(id)

      %AT.StartScript{
        ally_teams: [%{teams: [%{players: [%AT.Player{user_id: ^user_id}]}]}]
      } = start_script
    end

    test "with a spec" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2))

      start_script = LobbyProcess.get_start_script(id)
      user2_id = user2.id
      %{spectators: [%{user_id: ^user2_id}]} = start_script
    end

    test "with 2 players in the same team" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2))
      {:ok, _team_details} = Lobby.join_ally_team(id, user2.id, 0)

      start_script = LobbyProcess.get_start_script(id)
      %{ally_teams: [%{teams: [t1, t2]}]} = start_script
      %{players: [%{user_id: ^user_id}]} = t1
      %{players: [%{user_id: ^user2_id}]} = t2
    end

    test "1 ally team with a player leaving then joining" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2))
      {:ok, _team_details1} = Lobby.join_ally_team(id, user2_id, 0)
      :ok = Lobby.spectate(id, user_id)
      {:ok, _team_details2} = Lobby.join_ally_team(id, user_id, 0)

      start_script = LobbyProcess.get_start_script(id)
      %{ally_teams: [%{teams: [t1, t2]}]} = start_script
      %{players: [%{user_id: ^user2_id}]} = t1
      %{players: [%{user_id: ^user_id}]} = t2
    end

    test "2 ally teams" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2))
      {:ok, _team_details} = Lobby.join_ally_team(id, user2.id, 1)

      start_script = LobbyProcess.get_start_script(id)
      %{ally_teams: [%{teams: [t1]}, %{teams: [t2]}]} = start_script
      %{players: [%{user_id: ^user_id}]} = t1
      %{players: [%{user_id: ^user2_id}]} = t2
    end

    test "with a bot" do
      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([2, 2], user_id) |> Lobby.create()

      {:ok, _bot_id} = Lobby.add_bot(id, user_id, 1, "bot short name")
      start_script = LobbyProcess.get_start_script(id)
      %{ally_teams: [%{teams: [t1]}, %{teams: [t2]}]} = start_script
      %{players: [%{user_id: ^user_id}]} = t1
      %{bots: [%{host_user_id: ^user_id, ai_short_name: "bot short name"}]} = t2
      assert not is_map_key(t1, :bots)
      assert not is_map_key(t2, :players)
    end

    test "with an empty team" do
      startbox1 = %{top: 0, left: 0, bottom: 0.1, right: 0.1}
      startbox2 = %{top: 0, left: 0, bottom: 0.2, right: 0.2}
      startbox3 = %{top: 0, left: 0, bottom: 0.3, right: 0.3}

      at_config = [
        %LT.AllyTeamConfig{max_teams: 2, teams: [%{max_players: 1}], start_box: startbox1},
        %LT.AllyTeamConfig{max_teams: 2, teams: [%{max_players: 1}], start_box: startbox2},
        %LT.AllyTeamConfig{max_teams: 2, teams: [%{max_players: 1}], start_box: startbox3}
      ]

      user_id = AccountFixtures.user_fixture().id

      {:ok, _pid, %LT.Details{id: id}} =
        mk_start_params([1, 1, 1], user_id)
        |> Map.put(:ally_team_config, at_config)
        |> Lobby.create()

      user2 = AccountFixtures.user_fixture()
      user2_id = user2.id
      {:ok, _lobby_pid, _details} = Lobby.join(id, mk_player(user2))
      {:ok, _team_details} = Lobby.join_ally_team(id, user2_id, 2)

      start_script = LobbyProcess.get_start_script(id)

      # ally teams may not have empty teams, so they are filtered out. What
      # we really care about is the correct assignment of start box to ally teams
      assert %{ally_teams: [at1, at3]} = start_script

      %{start_box: ^startbox1, teams: [%{players: [%AT.Player{user_id: ^user_id}]}]} = at1
      %{start_box: ^startbox3, teams: [%{players: [%AT.Player{user_id: ^user2_id}]}]} = at3
    end
  end

  defp mk_player(user \\ nil) do
    user = user || AccountFixtures.user_fixture()
    %LT.PlayerJoinData{id: user.id, name: user.name}
  end

  # create a lobby with a few specs already in. Simplify the logic when
  # it comes to testing in-lobby interaction
  defp setup_full_lobby(teams \\ [2, 2], opts \\ []) do
    creator = AccountFixtures.user_fixture()

    {:ok, lobby_pid, %{id: id}} =
      mk_start_params(teams, creator.id)
      |> Map.put(:boss_enabled?, Keyword.get(opts, :boss_enabled?, false))
      |> Lobby.create()

    users =
      Enum.map([2, 3, 4, 5], fn _i ->
        {:ok, sink_pid} = Task.start_link(:timer, :sleep, [:infinity])
        player = AccountFixtures.user_fixture()
        player = mk_player(player)
        {:ok, _lobby_pid, _details} = Lobby.join(id, player, sink_pid)
        Map.put(player, :pid, sink_pid)
      end)

    {:ok, details} = LobbyProcess.get_details(id)
    assert map_size(details.players) == 1
    assert map_size(details.spectators) == 4

    # after getting the details, it should be guaranteed that all updates are
    # in the inbox, so no need to wait
    drain_msg_queue()

    %{lobby_pid: lobby_pid, id: id, creator_id: creator.id, users: users, details: details}
  end

  defp drain_msg_queue(timeout \\ 0, acc \\ []) do
    receive do
      msg -> drain_msg_queue(timeout, [msg | acc])
    after
      timeout -> Enum.reverse(acc)
    end
  end
end
