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
  def make_users_with_ranks(list_of_ranks) do
    users =
      Enum.with_index(list_of_ranks)
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
      |> Enum.map(fn x -> Map.put(x, :party_id, x.id) end)

    # set the user rank
    for {user, rank} <- Enum.zip(users, list_of_ranks) do
      Teiserver.Account.update_user_stat(user.id, %{
        :rank => rank
      })
    end

    users
  end

  test "load some players in and run a balance pass or two" do
    team_count = 2

    players =
      make_users_with_ranks([10, 20, 30, 40, 50, 60])

    dbg(players)

    players2 =
      players
      |> Enum.map(fn x -> Map.put(x, :userid, x.id) end)

    dbg(players2)

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(pid, :report_state)
    dbg(starting_state)

    first_balance_pass =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    state2 = GenServer.call(pid, :report_state)
    dbg(state2)

    second_balance_pass_hash_reuse =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    state3 = GenServer.call(pid, :report_state)
    dbg(state3)

    assert second_balance_pass_hash_reuse.hash == first_balance_pass.hash

    [_first_player | player_list_with_one_less_player] = players

    third_balance_pass_with_fewer_players =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], player_list_with_one_less_player}
      )

    assert second_balance_pass_hash_reuse.hash != third_balance_pass_with_fewer_players.hash
    dbg(GenServer.call(pid, :report_state))
  end

  test "get_balance_mode works with a hash" do
    team_count = 2

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(pid, :report_state)

    first_balance_pass =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    get_balance_mode_returns_value =
      GenServer.call(
        pid,
        :get_balance_mode
      )

    refute get_balance_mode_returns_value == nil
  end

  test "get_current_balance works with a hash" do
    team_count = 2

    players = make_users_with_ranks([10, 20, 30, 40])

    {:ok, pid} = BalancerServer.start_link(data: %{lobby_id: 1})

    starting_state = GenServer.call(pid, :report_state)

    first_balance_pass =
      GenServer.call(
        pid,
        {:make_balance, team_count, [], players}
      )

    get_balance_mode_returns_value =
      GenServer.call(pid, :get_current_balance)

    refute get_balance_mode_returns_value == nil
  end
end
