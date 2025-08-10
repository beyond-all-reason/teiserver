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
end
