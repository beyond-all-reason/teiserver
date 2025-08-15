defmodule Teiserver.TachyonLobby.LobbyTest do
  use Teiserver.DataCase
  import Teiserver.Support.Polling, only: [poll_until_some: 1, poll_until_nil: 1]
  alias Teiserver.TachyonLobby, as: Lobby

  @moduletag :tachyon

  test "create a lobby" do
    {:ok, pid, details} = Lobby.create(mk_start_params([1, 1]))
    p = poll_until_some(fn -> Lobby.lookup(details.id) end)
    assert p == pid
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

    test "can join lobby" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1, 1]))

      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _, details} = Lobby.join(id, mk_player("other-user-id"), sink_pid)
      assert details.members["other-user-id"].team == {1, 0, 0}

      assert_receive {:lobby, ^id,
                      {:updated, [%{event: :add_player, id: "other-user-id", team: {1, 0, 0}}]}}
    end

    test "join the most empty team" do
      # create a lobby 2 vs 15. Players should be put in the largest team
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 15]))
      {:ok, _, details} = Lobby.join(id, mk_player("user2"), self())
      assert details.members["user2"].team == {1, 0, 0}
      {:ok, _, details} = Lobby.join(id, mk_player("user3"), self())
      assert details.members["user3"].team == {1, 1, 0}
    end

    test "lobby full" do
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([1]))
      {:error, :lobby_full} = Lobby.join(id, mk_player("user2"), self())
    end

    test "participants get updated events on join" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _, _details} = Lobby.join(id, mk_player("user2"), sink_pid)

      assert_receive {:lobby, ^id,
                      {:updated, [%{id: "user2", event: :add_player, team: {1, 0, 0}}]}}
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

    test "leaving lobby send updates to remaining members" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_received {:lobby, ^id, {:updated, [%{event: :add_player}]}}

      :ok = Lobby.leave(id, "user2")
      assert_received {:lobby, ^id, {:updated, [%{event: :remove_player, id: "user2"}]}}
    end

    test "reshuffling player on leave sends updates" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user3"), sink_pid)
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user4"), sink_pid)

      assert_received {:lobby, ^id, {:updated, [%{event: :add_player}]}}
      assert_received {:lobby, ^id, {:updated, [%{event: :add_player}]}}
      assert_received {:lobby, ^id, {:updated, [%{event: :add_player}]}}

      :ok = Lobby.leave(id, "user2")
      assert_received {:lobby, ^id, {:updated, events}}

      expected =
        MapSet.new([
          %{event: :remove_player, id: "user2"},
          %{event: :change_player, id: "user4", team: {1, 0, 0}}
        ])

      assert expected == MapSet.new(events)
    end

    test "player pid dying means player is removed from lobby" do
      {:ok, sink_pid} = Task.start(:timer, :sleep, [:infinity])
      {:ok, _pid, %{id: id}} = Lobby.create(mk_start_params([2, 2]))
      {:ok, _pid, _details} = Lobby.join(id, mk_player("user2"), sink_pid)
      assert_receive {:lobby, ^id, {:updated, [%{event: :add_player}]}}

      Process.exit(sink_pid, :kill)
      assert_receive {:lobby, ^id, {:updated, [%{event: :remove_player, id: "user2"}]}}
    end
  end

  defp mk_start_params(teams) do
    %{
      creator_data: %{id: "1234"},
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

  defp mk_player(user_id) do
    %{id: user_id}
  end
end
