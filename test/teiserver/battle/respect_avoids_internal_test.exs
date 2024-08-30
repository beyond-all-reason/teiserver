defmodule Teiserver.Battle.RespectAvoidsInternalTest do
  @moduledoc """
  Can run all balance tests via
  mix test --only balance_test
  """
  use ExUnit.Case, async: false

  @moduletag :balance_test
  alias Teiserver.Battle.Balance.RespectAvoids

  test "can get lobby max avoids" do
    player_count = 14
    players_in_parties = 7
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 3

    players_in_parties = 6
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 4

    players_in_parties = 5
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 4

    players_in_parties = 4
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 5

    players_in_parties = 2
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 6

    players_in_parties = 0
    result = RespectAvoids.get_max_avoids(player_count, players_in_parties)
    assert result == 7
  end
end
