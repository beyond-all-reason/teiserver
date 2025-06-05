defmodule Teiserver.Matchmaking.AlgosTest do
  use ExUnit.Case
  alias Teiserver.Matchmaking.Member
  alias Teiserver.Matchmaking.Algos

  describe "ignore OS" do
    test "no members" do
      assert Algos.ignore_os(1, 2, []) == :no_match
    end

    test "not enough to fill one team" do
      members = [mk_member(1)]
      assert Algos.ignore_os(1, 2, members) == :no_match
    end

    test "one team" do
      members = [m1, m2] = [mk_member(1), mk_member(2)]
      assert {:match, [team]} = Algos.ignore_os(1, 2, members)
      assert MapSet.new(team) == MapSet.new([[m1], [m2]])
    end

    test "two teams" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [_team1, _team2]} = Algos.ignore_os(1, 2, members)
    end

    test "more teams" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [team]} = Algos.ignore_os(1, 3, members)
      assert Enum.count(team) == 3
    end

    test "bigger team" do
      members = Enum.map(1..3, &mk_member/1)
      assert :no_match = Algos.ignore_os(2, 2, members)
    end

    test "bigger team with match" do
      members = Enum.map(1..4, &mk_member/1)
      assert {:match, [_team]} = Algos.ignore_os(2, 2, members)
    end

    test "bigger team with party" do
      members = [mk_member([1, 2]), mk_member(3), mk_member(4)]
      assert {:match, [team]} = Algos.ignore_os(2, 2, members)
      counts = Enum.map(team, &Enum.count/1)
      assert MapSet.new(counts) == MapSet.new([1, 2])
    end

    test "bigger team with party, different ordering" do
      members = [mk_member(0), mk_member([1, 2]), mk_member(3)]
      assert {:match, [team]} = Algos.ignore_os(2, 2, members)
      counts = Enum.map(team, &Enum.count/1)
      assert MapSet.new(counts) == MapSet.new([1, 2])
    end

    test "ordering doesn't matter" do
      members = [mk_member(0), mk_member(1), mk_member([2, 3]), mk_member([4, 5])]
      assert {:match, _} = Algos.ignore_os(3, 2, members)
    end
  end

  defp mk_member(ids) when not is_list(ids), do: mk_member([ids])

  defp mk_member(ids) do
    %Member{
      id: UUID.uuid4(),
      player_ids: ids,
      rating: %{},
      avoid: [],
      joined_at: DateTime.utc_now()
    }
  end
end
