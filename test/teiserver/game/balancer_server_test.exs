defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false
  use Teiserver.DataCase, async: false

  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  test "get fuzz multiplier" do
    result = BalancerServer.get_fuzz_multiplier([])
    assert result == 0

    result = BalancerServer.get_fuzz_multiplier(algorithm: "loser_picks", fuzz_multiplier: 0.5)
    assert result == 0.5

    result = BalancerServer.get_fuzz_multiplier(algorithm: "split_noobs", fuzz_multiplier: 0.5)

    assert result == 0
  end

  test "calculate team size" do
    team_count = 2
    players = create_fake_players(1)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 1

    players = create_fake_players(2)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 1

    players = create_fake_players(6)
    assert Enum.count(players) == 6
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 3

    players = create_fake_players(7)
    result = BalancerServer.calculate_team_size(team_count, players)
    assert result == 4
  end

  test "load some players in and run a balance pass or two" do
    team_count = 2
    players = create_fake_players(4)
    _team_size = BalancerServer.calculate_team_size(team_count, players)

    # spin up a lobby
    lobby_starter_info = %{
      "ip" => nil,
      "port" => nil,
      "engine_version" => nil,
      "map_hash" => nil,
      "map_name" => nil,
      "game_name" => nil,
      "hash_code" => nil,
      "founder_id" => 4,
      "founder_name" => "root",
      "name" => "asdf",
      "locked" => false,
      "type" => "normal",
      "nattype" => "none"
    }

    {:ok, lobby} =
      Teiserver.Lobby.create_new_lobby(lobby_starter_info)

    # put some users in the lobby
    users = Teiserver.Account.list_users(limit: 4)
    _ = Enum.map(users, fn user -> Teiserver.Lobby.force_add_user_to_lobby(user.id, lobby.id) end)

    # ask for the initial balance state of the lobby
    {:ok, balance_server_init_results} = BalancerServer.init(%{lobby_id: lobby.id})

    {:ok, start_link_results} = BalancerServer.start_link(data: balance_server_init_results)

    assert is_pid(start_link_results)
    state = :sys.get_state(start_link_results)

    state = GenServer.call(start_link_results, :report_state)
    dbg(state)
    # list the players in the lobby
    players = Teiserver.Battle.list_lobby_players(lobby.id)
    dbg(players)
    assert Enum.any?(players)

    # there should be some players in the lobby, and from there we could run a balance pass and get a hash,
    # but we don't have any players in the lobby for some reason...
  end

  defp create_fake_players(count) do
    1..count |> Enum.map(fn _ -> %{} end)
  end
end
