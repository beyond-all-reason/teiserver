defmodule Teiserver.Battle.BalanceLibTest do
  use Central.DataCase, async: true
  alias Teiserver.Battle.BalanceLib
  # alias Teiserver.TeiserverTestLib

  test "loser picks simple users" do
    result = BalanceLib.create_balance(
      [
        {[1], 5},
        {[2], 6},
        {[3], 7},
        {[4], 8},
      ],
      2,
      :loser_picks
    )

    assert result == %{
      team_groups: %{
        1 => [{[4], 8, 1}, {[1], 5, 1}],
        2 => [{[3], 7, 1}, {[2], 6, 1}]
      },
      team_players: %{
        1 => [4, 1],
        2 => [3, 2]
      },
      ratings: %{
        1 => 13,
        2 => 13
      },
      captains: %{
        1 => 4,
        2 => 3
      },
      team_sizes: %{
        1 => 2,
        2 => 2
      },
      deviation: {1, 0}
    }
  end

  test "loser picks simple group" do
    result = BalanceLib.create_balance(
      [
        {[4, 1], 5 + 8},
        {[2], 6},
        {[3], 7}
      ],
      2,
      :loser_picks
    )

    assert result == %{
      team_groups: %{
        1 => [{[4, 1], 13, 2}],
        2 => [{[3], 7, 1}, {[2], 6, 1}]
      },
      team_players: %{
        1 => [4, 1],
        2 => [3, 2]
      },
      ratings: %{
        1 => 13,
        2 => 13
      },
      captains: %{
        1 => 4,
        2 => 3
      },
      team_sizes: %{
        1 => 2,
        2 => 2
      },
      deviation: {1, 0}
    }
  end

  test "loser picks bigger game group" do
    result = BalanceLib.create_balance(
      [
        # Two high tier players partied together
        {[1, 2], 41 + 35},

        # A bunch of mid-low tier players together
        {[3, 4, 5], 20 + 17 + 13},

        # A smaller bunch of even lower tier players
        {[6, 7], 15 + 9},

        # Other players, a range of ratings
        {[8], 31},
        {[9], 26},
        {[10], 25},
        {[11], 21},
        {[12], 19},
        {[13], 16},
        {[14], 16},
        {[15], 14},
        {[16], 8}
      ],
      2,
      :loser_picks
    )

    assert result == %{
      team_groups: %{
        1 => [{[1, 2], 76, 2}, {[9], 26, 1}, {[6, 7], 24, 2}, {[12], 19, 1}, {[15], 14, 1}, {[16], 8, 1}],
        2 => [{[3, 4, 5], 50, 3}, {[8], 31, 1}, {[10], 25, 1}, {[11], 21, 1}, {[13], 16, 1}, {[14], 16, 1}]
      },
      team_players: %{
        1 => [1, 2, 9, 6, 7, 12, 15, 16],
        2 => [3, 4, 5, 8, 10, 11, 13, 14]
      },
      ratings: %{
        1 => 167,
        2 => 159
      },
      captains: %{
        1 => 1,
        2 => 3
      },
      team_sizes: %{
        1 => 8,
        2 => 8
      },
      deviation: {1, 5}
    }
  end
end
