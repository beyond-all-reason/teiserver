defmodule Teiserver.Game.BalancerServerAsyncTest do
  @moduledoc false
  use ExUnit.Case, async: true

  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  defp create_fake_players(count) do
    1..count |> Enum.map(fn _ -> %{} end)
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
  use Teiserver.DataCase, async: false
  import Teiserver.Support.Polling, only: [poll_until_nil: 1]

  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  @spec make_users_with_ranks([non_neg_integer()]) ::
          list()

  def make_users_with_ranks(list_of_ranks) do
    users =
      for {rank, i} <- Enum.with_index(list_of_ranks) do
        user = Central.Helpers.GeneralTestLib.make_user(%{})
        user = Map.put(user, :party_id, i)
        user = Map.put(user, :userid, user.id)

        Teiserver.Account.update_user_stat(user.id, %{
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
    refute Map.get(GenServer.call(pid, :report_state), :last_balance_result, :not_found) == nil

    GenServer.cast(
      pid,
      :reset_hashes
    )

    poll_until_nil(fn -> GenServer.call(pid, :get_current_balance) end)
    assert Map.get(GenServer.call(pid, :report_state), :last_balance_hash, :not_found) == nil
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
    refute Map.get(GenServer.call(pid, :report_state), :last_balance_result, :not_found) == nil

    GenServer.cast(
      pid,
      {:set, :rating_upper_boundary, 100}
    )

    poll_until_nil(fn -> GenServer.call(pid, :get_current_balance) end)
    assert Map.get(GenServer.call(pid, :report_state), :last_balance_hash, :not_found) == nil
  end
end
