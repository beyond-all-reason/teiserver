defmodule Teiserver.Game.BalancerServerTest do
  @moduledoc false
  use Teiserver.DataCase, async: false

  @moduletag :balance_test
  alias Teiserver.Game.BalancerServer

  def user_fixture(), do: make_user(%{"permissions" => []})

  def make_user(params \\ %{}) do
    requested_user = %{
      "name" => params["name"] || "Test",
      "email" => params["email"] || "email@email#{:rand.uniform(999_999_999_999)}",
      "colour" => params["colour"] || "#00AA00",
      "icon" => params["icon"] || "fa-solid fa-user",
      "password" => params["password"] || "password",
      "password_confirmation" => params["password"] || "password",
      "data" => params["data"] || %{}
    }

    {:ok, u} =
      Teiserver.Account.create_user(requested_user)
  end

  @spec make_users_with_ranks([non_neg_integer()]) ::
          list()
  def make_users_with_ranks(list_of_ranks_to_assign_to_users) do
    users =
      Enum.with_index(list_of_ranks_to_assign_to_users)
      |> Enum.map(fn {user, index} ->
        %{
          "name" => "user" <> to_string(index + 1) <> "_" <> to_string(ExULID.ULID.generate()),
          "email" => to_string(ExULID.ULID.generate()) <> "@example.com",
          "permissions" => []
        }
      end)
      |> Enum.map(fn x -> make_user(x) end)
      # unwrap user creation response
      |> Enum.map(fn {:ok, reply} -> reply end)
      |> Enum.map(fn x -> Map.put(x, :userid, x.id) end)
      # each user in their own party
      |> Enum.map(fn x -> Map.put(x, :party_id, x.id + 1) end)

    # set the user rank
    Enum.map(Enum.with_index(users), fn {user, index} ->
      Teiserver.Account.update_user_stat(user.id, %{
        :rank => Enum.at(list_of_ranks_to_assign_to_users, index)
      })
    end)

    users
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

  test "load some players in and run a balance pass or two" do
    team_count = 2

    arbitrary_rank_for_all_test_users = 10

    players =
      make_users_with_ranks([10, 20, 30, 40])

    dbg(players)

    players2 =
      players
      |> Enum.map(fn x -> Map.put(x, :userid, x.id) end)

    dbg(players2)

    {:ok, start_link_results} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(start_link_results, :report_state, 5000)
    dbg(starting_state)

    first_balance_pass =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], players},
        5000
      )

    state2 = GenServer.call(start_link_results, :report_state, 5000)
    dbg(state2)

    second_balance_pass_hash_reuse =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], players},
        5000
      )

    state3 = GenServer.call(start_link_results, :report_state, 5000)
    dbg(state3)

    assert second_balance_pass_hash_reuse.hash == first_balance_pass.hash

    # users = [
    #   make_user(%{
    #     "name" => "user"+ExULID.ULID.generate(),
    #     "email" => ExULID.ULID.generate()+"@example.com",
    #     "permissions" => []
    #   }),
    #   make_user(%{
    #     "name" => "user2",
    #     "email" => "user2-test542684@example.com",
    #     "permissions" => []
    #   }),
    #   make_user(%{
    #     "name" => "user3",
    #     "email" => "user3-test542684@example.com",
    #     "permissions" => []
    #   }),
    #   make_user(%{
    #     "name" => "user4",
    #     "email" => "user4-test542684@example.com",
    #     "permissions" => []
    #   }),
    #   make_user(%{
    #     "name" => "user5",
    #     "email" => "user5-test542684@example.com",
    #     "permissions" => []
    #   })
    # ]

    #### TODO

    # third_balance_pass_with_more_players =
    #   GenServer.call(
    #     start_link_results,
    #     {:make_balance, team_count, [], create_fake_players(160)},
    #     5000
    #   )

    # dbg(third_balance_pass_with_more_players)
    # assert second_balance_pass_hash_reuse.hash != third_balance_pass_with_more_players.hash
  end

  test "get_balance_mode works with a hash" do
    team_count = 2

    arbitrary_rank_for_all_test_users = 10

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, start_link_results} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(start_link_results, :report_state, 5000)

    first_balance_pass =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], players},
        5000
      )

    get_balance_mode_returns_value =
      GenServer.call(
        start_link_results,
        :get_balance_mode,
        5000
      )

    refute get_balance_mode_returns_value == nil
  end

  test "get_current_balance works with a hash" do
    team_count = 2

    arbitrary_rank_for_all_test_users = 10

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, start_link_results} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(start_link_results, :report_state, 5000)

    first_balance_pass =
      GenServer.call(
        start_link_results,
        {:make_balance, team_count, [], players},
        5000
      )

    get_balance_mode_returns_value =
      GenServer.call(
        start_link_results,
        :get_current_balance,
        5000
      )

    refute get_balance_mode_returns_value == nil
  end

  defp create_fake_players(count) do
    1..count |> Enum.map(fn iter -> %{iter: iter} end)
  end
end
