defmodule TeiserverWeb.Battle.MatchLive.ShowTest do
  alias TeiserverWeb.Battle.MatchLive.Show
  use Teiserver.DataCase, async: true

  @player_stats %{
    team1_player1: %{
      "damageDealt" => 100,
      "damageReceived" => 50,
      "metalProduced" => 200,
      "metalUsed" => 150,
      "energyProduced" => 300,
      "energyUsed" => 250
    },
    team1_player2: %{
      "damageDealt" => 200,
      "damageReceived" => 100,
      "metalProduced" => 300,
      "metalUsed" => 250,
      "energyProduced" => 400,
      "energyUsed" => 350
    },
    team2_player1: %{
      "damageDealt" => 150,
      "damageReceived" => 75,
      "metalProduced" => 250,
      "metalUsed" => 200,
      "energyProduced" => 350,
      "energyUsed" => 300
    },
    team2_player2: %{
      "damageDealt" => 250,
      "damageReceived" => 125,
      "metalProduced" => 350,
      "metalUsed" => 300,
      "energyProduced" => 450,
      "energyUsed" => 400
    }
  }

  # Expected team total stat values for tests
  @team_totals %{
    empty_team: %{
      players: 2,
      damage_done: 0,
      damage_taken: 0,
      metal_produced: 0,
      metal_used: 0,
      energy_produced: 0,
      energy_used: 0
    },
    team1: %{
      players: 2,
      damage_done: 300,
      damage_taken: 150,
      metal_produced: 500,
      metal_used: 400,
      energy_produced: 700,
      energy_used: 600
    },
    team2: %{
      players: 2,
      damage_done: 400,
      damage_taken: 200,
      metal_produced: 600,
      metal_used: 500,
      energy_produced: 800,
      energy_used: 700
    }
  }

  defp player_stats(player_key), do: @player_stats[player_key]

  defp make_player(user_id, team_id, stats \\ %{}) do
    %{team_id: team_id, user_id: user_id, stats: stats}
  end

  defp assert_team_totals(totals, team_id, expected) do
    assert totals[team_id].players == expected.players
    assert totals[team_id].stats["damageDealt"] == expected.damage_done
    assert totals[team_id].stats["damageReceived"] == expected.damage_taken
    assert totals[team_id].stats["metalProduced"] == expected.metal_produced
    assert totals[team_id].stats["metalUsed"] == expected.metal_used
    assert totals[team_id].stats["energyProduced"] == expected.energy_produced
    assert totals[team_id].stats["energyUsed"] == expected.energy_used
  end

  test "get team id" do
    team_players = %{1 => [1, 4], 2 => [2, 3]}
    player_id = 4
    result = Show.get_team_id(player_id, team_players)
    assert result == 0

    player_id = 3
    result = Show.get_team_id(player_id, team_players)
    assert result == 1
  end

  describe "should_show_team_total?/2" do
    test "duel matches never show team totals" do
      members = [
        make_player(1, 0),
        make_player(2, 1)
      ]

      refute Show.should_show_team_total?(members, hd(members))
      refute Show.should_show_team_total?(members, List.last(members))
    end

    test "shows team total stats after last player in each team in team games" do
      members = [
        make_player(1, 0),
        make_player(2, 0),
        make_player(3, 1),
        make_player(4, 1)
      ]

      refute Show.should_show_team_total?(members, Enum.at(members, 0))
      assert Show.should_show_team_total?(members, Enum.at(members, 1))
      refute Show.should_show_team_total?(members, Enum.at(members, 2))
      assert Show.should_show_team_total?(members, Enum.at(members, 3))
    end

    test "shows team totals for uneven teams (2v1)" do
      members = [
        make_player(1, 0),
        make_player(2, 0),
        make_player(3, 1)
      ]

      refute Show.should_show_team_total?(members, Enum.at(members, 0))
      assert Show.should_show_team_total?(members, Enum.at(members, 1))
      # Teams with only one player should not show team stat totals
      refute Show.should_show_team_total?(members, Enum.at(members, 2))
    end

    test "never shows team totals in free-for-all games (1v1v1)" do
      members = [
        make_player(1, 0),
        make_player(2, 1),
        make_player(3, 2)
      ]

      refute Show.should_show_team_total?(members, Enum.at(members, 0))
      refute Show.should_show_team_total?(members, Enum.at(members, 1))
      refute Show.should_show_team_total?(members, Enum.at(members, 2))
    end
  end

  describe "calculate_team_totals/1" do
    test "handles empty stats" do
      members = [
        make_player(1, 0, %{}),
        make_player(2, 0, %{}),
        make_player(3, 1, %{}),
        make_player(4, 1, %{})
      ]

      totals = Show.calculate_team_totals(members)

      assert_team_totals(totals, 0, @team_totals.empty_team)
      assert_team_totals(totals, 1, @team_totals.empty_team)
    end

    test "calculates totals for 2v2 teams" do
      members = [
        make_player(1, 0, player_stats(:team1_player1)),
        make_player(2, 0, player_stats(:team1_player2)),
        make_player(3, 1, player_stats(:team2_player1)),
        make_player(4, 1, player_stats(:team2_player2))
      ]

      totals = Show.calculate_team_totals(members)

      assert_team_totals(totals, 0, @team_totals.team1)
      assert_team_totals(totals, 1, @team_totals.team2)
    end

    test "calculates totals for uneven teams (2v1)" do
      members = [
        make_player(1, 0, player_stats(:team1_player1)),
        make_player(2, 0, player_stats(:team1_player2)),
        make_player(3, 1, player_stats(:team2_player1))
      ]

      totals = Show.calculate_team_totals(members)

      # Team 0 has multiple players, so should have total stats
      assert_team_totals(totals, 0, @team_totals.team1)

      # Team 1 has only one player, so should not have total stats
      refute Map.has_key?(totals, 1)
    end

    test "skips totals for teams with only one player" do
      members = [
        make_player(1, 0, player_stats(:team1_player1)),
        make_player(2, 1, player_stats(:team2_player1))
      ]

      totals = Show.calculate_team_totals(members)

      # Both teams have only one player, so no total stats should be calculated
      assert totals == %{}
    end

    test "skips totals for free-for-all games (1v1v1)" do
      members = [
        make_player(1, 0, player_stats(:team1_player1)),
        make_player(2, 1, player_stats(:team1_player2)),
        make_player(3, 2, player_stats(:team2_player1))
      ]

      totals = Show.calculate_team_totals(members)

      # Free-for-all games have no team total stats since each player is their own team
      assert totals == %{}
    end
  end
end
