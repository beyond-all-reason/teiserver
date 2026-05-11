defmodule Teiserver.Game.BalancerServerAsyncTest do
  @moduledoc false

  alias Teiserver.Game.BalancerServer

  use ExUnit.Case, async: true

  @moduletag :balance_test

  defp create_fake_players(count) do
    1..count |> Enum.map(fn _i -> %{} end)
  end

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
end

defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false

  alias Teiserver.Account
  alias Teiserver.Game.BalancerServer
  alias Teiserver.Helpers.GeneralTestLib

  use Teiserver.DataCase, async: false

  import Teiserver.Support.Polling, only: [poll_until_nil: 1]

  @moduletag :balance_test

  @spec make_users_with_ranks([non_neg_integer()]) ::
          list()

  def make_users_with_ranks(list_of_ranks) do
    users =
      for {rank, i} <- Enum.with_index(list_of_ranks) do
        user =
          GeneralTestLib.make_user(%{})
          |> Map.put(:party_id, i)
          |> then(fn user -> Map.put(user, :userid, user.id) end)

        Account.update_user_stat(user.id, %{
          :rank => rank
        })

        user
      end

    users
  end

  test "load some players in and run a balance pass or three, checking if the cache was hit" do
    team_count = 2

    players =
      make_users_with_ranks([10, 20, 30, 40, 50, 60])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    first_balance_pass =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    second_balance_pass_hash_reuse =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    assert second_balance_pass_hash_reuse === first_balance_pass

    player_list_with_one_less_player = tl(players)

    third_balance_pass_with_fewer_players =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], player_list_with_one_less_player}
      )

    refute second_balance_pass_hash_reuse.hash == third_balance_pass_with_fewer_players.hash

    refute second_balance_pass_hash_reuse.team_sizes ==
             third_balance_pass_with_fewer_players.team_sizes

    refute second_balance_pass_hash_reuse.team_groups ==
             third_balance_pass_with_fewer_players.team_groups

    refute second_balance_pass_hash_reuse.logs == third_balance_pass_with_fewer_players.logs
  end

  test "get_current_balance returns a result" do
    team_count = 2

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    GenServer.call(
      pid,
      {:make_balance, team_count, [], players}
    )

    refute GenServer.call(pid, :get_current_balance) == nil
  end

  test "reset_hashes clears hash and result" do
    team_count = 2

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    GenServer.call(
      pid,
      {:make_balance, team_count, [], players}
    )

    refute GenServer.call(pid, :get_current_balance) == nil
    refute GenServer.call(pid, :report_state) |> Map.get(:last_balance_result, :not_found) == nil

    GenServer.cast(
      pid,
      :reset_hashes
    )

    poll_until_nil(fn -> GenServer.call(pid, :get_current_balance) end)
    assert GenServer.call(pid, :report_state) |> Map.get(:last_balance_hash, :not_found) == nil
  end

  test "setting the balance mode clears the hash and result" do
    team_count = 2

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    GenServer.call(
      pid,
      {:make_balance, team_count, [], players}
    )

    refute GenServer.call(pid, :get_current_balance) == nil
    refute GenServer.call(pid, :report_state) |> Map.get(:last_balance_result, :not_found) == nil

    GenServer.cast(
      pid,
      {:set, :rating_upper_boundary, 100}
    )

    poll_until_nil(fn -> GenServer.call(pid, :get_current_balance) end)
    assert GenServer.call(pid, :report_state) |> Map.get(:last_balance_hash, :not_found) == nil
  end

  test "shuffle_teams swaps all team-keyed maps between team 1 and team 2" do
    result = %{
      team_players: %{1 => [101], 2 => [202]},
      team_groups: %{1 => [:group_a], 2 => [:group_b]},
      ratings: %{1 => 10.0, 2 => 20.0},
      captains: %{1 => 101, 2 => 202},
      team_sizes: %{1 => 1, 2 => 1},
      means: %{1 => 10.0, 2 => 20.0},
      stdevs: %{1 => 0.0, 2 => 0.0},
      logs: ["some log"],
      deviation: 5
    }

    swapped = BalancerServer.shuffle_teams(result, %{1 => 2, 2 => 1})

    assert swapped.team_players == %{1 => [202], 2 => [101]}
    assert swapped.team_groups == %{1 => [:group_b], 2 => [:group_a]}
    assert swapped.ratings == %{1 => 20.0, 2 => 10.0}
    assert swapped.captains == %{1 => 202, 2 => 101}
    assert swapped.team_sizes == %{1 => 1, 2 => 1}
    assert swapped.means == %{1 => 20.0, 2 => 10.0}
    assert swapped.stdevs == %{1 => 0.0, 2 => 0.0}
    assert swapped.logs == result.logs
    assert swapped.deviation == result.deviation
  end

  test "shuffle_teams do not break Team FFA (even teams)" do
    mapping = %{1 => 2, 2 => 3, 3 => 4, 4 => 1}

    result = %{
      team_players: %{1 => [101], 2 => [202], 3 => [303], 4 => [404]},
      team_groups: %{1 => [:group_a], 2 => [:group_b], 3 => [:group_c], 4 => [:group_d]},
      ratings: %{1 => 10.0, 2 => 11.0, 3 => 12.0, 4 => 13.0},
      captains: %{1 => 101, 2 => 202, 3 => 303, 4 => 404},
      team_sizes: %{1 => 1, 2 => 1, 3 => 1, 4 => 1},
      means: %{1 => 10.0, 2 => 11.0, 3 => 12.0, 4 => 13.0},
      stdevs: %{1 => 0.0, 2 => 0.0, 3 => 0.0, 4 => 0.0},
      logs: ["some log"],
      deviation: 5
    }

    swapped = BalancerServer.shuffle_teams(result, mapping)

    assert swapped.team_players == %{2 => [101], 3 => [202], 4 => [303], 1 => [404]}
    assert swapped.ratings == %{2 => 10.0, 3 => 11.0, 4 => 12.0, 1 => 13.0}
    assert swapped.logs == result.logs
    assert swapped.deviation == result.deviation
  end

  test "shuffle_teams do not break Team FFA (odd teams)" do
    mapping = %{1 => 3, 2 => 1, 3 => 2}

    result = %{
      team_players: %{1 => [101], 2 => [202], 3 => [303]},
      team_groups: %{1 => [:group_a], 2 => [:group_b], 3 => [:group_c]},
      ratings: %{1 => 10.0, 2 => 11.0, 3 => 12.0},
      captains: %{1 => 101, 2 => 202, 3 => 303},
      team_sizes: %{1 => 1, 2 => 1, 3 => 1},
      means: %{1 => 10.0, 2 => 11.0, 3 => 12.0},
      stdevs: %{1 => 0.0, 2 => 0.0, 3 => 0.0},
      logs: ["some log"],
      deviation: 5
    }

    swapped = BalancerServer.shuffle_teams(result, mapping)

    assert swapped.team_players == %{3 => [101], 1 => [202], 2 => [303]}
    assert swapped.ratings == %{3 => 10.0, 1 => 11.0, 2 => 12.0}
    assert swapped.logs == result.logs
    assert swapped.deviation == result.deviation
  end

  test "shuffle_teams (2 teams) is its own inverse" do
    result = %{
      team_players: %{1 => [101, 102], 2 => [201, 202]},
      ratings: %{1 => 15.0, 2 => 25.0}
    }

    assert result
           |> BalancerServer.shuffle_teams(%{1 => 2, 2 => 1})
           |> BalancerServer.shuffle_teams(%{1 => 2, 2 => 1}) == result
  end
end
