defmodule Teiserver.Matchmaking.AlgosTest do
  alias Teiserver.Matchmaking.Algo.BruteforceFilter
  alias Teiserver.Matchmaking.Algo.Env
  alias Teiserver.Matchmaking.Algo.IgnoreOs
  alias Teiserver.Matchmaking.Member
  use ExUnit.Case

  def ignore_os(members, team_size, team_count) do
    st = IgnoreOs.init(team_size, team_count)
    IgnoreOs.get_matches(members, st, Env.default_env())
  end

  def brutefore_filter(members, team_size, team_count, env \\ nil) do
    st = BruteforceFilter.init(team_size, team_count)
    env = env || Env.default_env()
    BruteforceFilter.get_matches(members, st, env)
  end

  describe "ignore OS" do
    test "no members" do
      assert ignore_os([], 1, 2) == :no_match
    end

    test "not enough to fill one team" do
      members = [mk_member(1)]
      assert ignore_os(members, 1, 2) == :no_match
    end

    test "one team" do
      members = [m1, m2] = [mk_member(1), mk_member(2)]
      assert {:match, [team]} = ignore_os(members, 1, 2)
      assert MapSet.new(team) == MapSet.new([[m1], [m2]])
    end

    test "two teams" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [_team1, _team2]} = ignore_os(members, 1, 2)
    end

    test "more teams" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [team]} = ignore_os(members, 1, 3)
      assert Enum.count(team) == 3
    end

    test "bigger team" do
      members = Enum.map(1..3, &mk_member/1)
      assert :no_match = ignore_os(members, 2, 2)
    end

    test "bigger team with match" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [_team]} = ignore_os(members, 2, 2)
    end

    test "bigger team with party" do
      members = [mk_member([1, 2]), mk_member(3), mk_member(4)]
      assert {:match, [team]} = ignore_os(members, 2, 2)
      counts = Enum.map(team, &Enum.count/1)
      assert MapSet.new(counts) == MapSet.new([1, 2])
    end

    test "bigger team with party, different ordering" do
      members = [mk_member(0), mk_member([1, 2]), mk_member(3)]
      assert {:match, [team]} = ignore_os(members, 2, 2)
      counts = Enum.map(team, &Enum.count/1)
      assert MapSet.new(counts) == MapSet.new([1, 2])
    end

    test "ordering doesn't matter" do
      members = [mk_member(0), mk_member(1), mk_member([2, 3]), mk_member([4, 5])]
      assert {:match, _teams} = ignore_os(members, 3, 2)
    end
  end

  describe "bruteforce filter" do
    test "works" do
      [m1, m2] = members = Enum.map(1..2, &mk_member/1)
      assert {:match, [[t1, t2]]} = brutefore_filter(members, 1, 2)
      assert [m1] == t1
      assert [m2] == t2
    end

    test "properly exclude unbalanced match" do
      # 2 players are very low OS, and one is super high
      members = [mk_member(1, 1), mk_member(2, 60), mk_member(3, 1)]

      assert {:match, [match]} = brutefore_filter(members, 1, 2)
      matched_ids = for team <- match, member <- team, p_id <- member.player_ids, do: p_id
      assert MapSet.new(matched_ids) == MapSet.new([1, 3])
    end

    test "take into account how long a member has been in queue" do
      members = [mk_member(1, 10), mk_member(2, 20)]
      assert :no_match = brutefore_filter(members, 1, 2)

      env = %Env{now: DateTime.utc_now() |> DateTime.shift(second: 30)}
      assert {:match, [_match]} = brutefore_filter(members, 1, 2, env)
    end

    test "both members should have waited long enough" do
      members = [
        # only member 1 has been waiting for some time
        mk_member(1, 10)
        |> Map.put(:joined_at, DateTime.utc_now() |> DateTime.shift(second: -30)),
        mk_member(2, 20)
      ]

      assert :no_match = brutefore_filter(members, 1, 2)
    end
  end

  defp mk_member(ids, rating \\ {17, 6})
  defp mk_member(ids, rating) when not is_list(ids), do: mk_member([ids], rating)
  defp mk_member(ids, rating) when is_number(rating), do: mk_member(ids, {rating, 6})

  defp mk_member(ids, {skill, uncertainty}) do
    %Member{
      id: UUID.uuid4(),
      player_ids: ids,
      rating: %{skill: skill, uncertainty: uncertainty},
      avoid: [],
      joined_at: DateTime.utc_now()
    }
  end
end
