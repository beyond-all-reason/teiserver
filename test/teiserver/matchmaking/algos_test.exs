defmodule Teiserver.Matchmaking.AlgosTest do
  use ExUnit.Case
  alias Teiserver.Matchmaking.Member
  alias Teiserver.Matchmaking.Algo

  def ignore_os(members, team_size, team_count) do
    st = Algo.IgnoreOs.init(team_size, team_count)
    Algo.IgnoreOs.get_matches(members, st)
  end

  def brutefore_filter(members, team_size, team_count) do
    st = Algo.BruteforceFilter.init(team_size, team_count)
    Algo.BruteforceFilter.get_matches(members, st)
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
      assert {:match, _} = ignore_os(members, 3, 2)
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
