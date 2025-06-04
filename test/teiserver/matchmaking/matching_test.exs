defmodule Teiserver.MatchingTest do
  use ExUnit.Case
  import Teiserver.Matchmaking.QueueServer, only: [match_members: 1, init_state: 1]
  alias Teiserver.Matchmaking.Member

  test "no members" do
    state = mk_state(1, 2, [])
    assert match_members(state) == :no_match
  end

  test "not enough to fill one team" do
    state = mk_state(1, 2, [mk_member(1)])
    assert match_members(state) == :no_match
  end

  test "one team" do
    [m1, m2] = [mk_member(1), mk_member(2)]
    state = mk_state(1, 2, [m1, m2])
    assert {:match, [team]} = match_members(state)
    assert MapSet.new(team) == MapSet.new([[m1], [m2]])
  end

  test "two teams" do
    members = Enum.map(1..4, &mk_member/1)
    state = mk_state(1, 2, members)
    assert {:match, [_team1, _team2]} = match_members(state)
  end

  test "more teams" do
    members = Enum.map(1..4, &mk_member/1)
    state = mk_state(1, 3, members)
    assert {:match, [team]} = match_members(state)
    assert Enum.count(team) == 3
  end

  test "bigger team" do
    members = Enum.map(1..3, &mk_member/1)
    state = mk_state(2, 2, members)
    assert :no_match = match_members(state)
  end

  test "bigger team with match" do
    members = Enum.map(1..4, &mk_member/1)
    state = mk_state(2, 2, members)
    assert {:match, [_team]} = match_members(state)
  end

  test "bigger team with party" do
    members = [mk_member([1, 2]), mk_member(3), mk_member(4)]
    state = mk_state(2, 2, members)
    assert {:match, [team]} = match_members(state)
    counts = Enum.map(team, &Enum.count/1)
    assert MapSet.new(counts) == MapSet.new([1, 2])
  end

  test "bigger team with party, different ordering" do
    members = [mk_member(0), mk_member([1, 2]), mk_member(3)]
    state = mk_state(2, 2, members)
    assert {:match, [team]} = match_members(state)
    counts = Enum.map(team, &Enum.count/1)
    assert MapSet.new(counts) == MapSet.new([1, 2])
  end

  defp mk_state(team_size, team_count, members) do
    init_state(%{
      id: "iiiiiiid",
      name: "naaaaaame",
      team_size: team_size,
      team_count: team_count,
      members: members
    })
  end

  defp mk_member(ids) when not is_list(ids), do: mk_member([ids])

  defp mk_member(ids) do
    %Member{
      player_ids: ids,
      rating: %{},
      avoid: [],
      joined_at: DateTime.utc_now(),
      search_distance: 0,
      increase_distance_after: 10
    }
  end
end
