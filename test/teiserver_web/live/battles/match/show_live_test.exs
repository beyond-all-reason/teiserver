defmodule TeiserverWeb.Battle.MatchLive.ShowTest do
  alias TeiserverWeb.Battle.MatchLive.Show
  use ExUnit.Case

  test "get team id" do
    team_players = %{1 => [1, 4], 2 => [2, 3]}
    player_id = 4
    result = Show.get_team_id(player_id, team_players)
    assert result == 0

    player_id = 3
    result = Show.get_team_id(player_id, team_players)
    assert result == 1
  end
end
