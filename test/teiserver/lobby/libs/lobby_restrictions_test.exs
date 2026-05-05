defmodule Teiserver.Lobby.Libs.LobbyRestrictionsTest do
  @moduledoc false

  alias Teiserver.Lobby.LobbyRestrictions
  use ExUnit.Case

  test "check for noob title" do
    # Noob titles
    assert LobbyRestrictions.noob_title?("Noobs 1v1")
    assert LobbyRestrictions.noob_title?("Newbies 1v1")
    assert LobbyRestrictions.noob_title?("Nubs 1v1")
    assert LobbyRestrictions.noob_title?("N00bz")
    assert LobbyRestrictions.noob_title?("Newbz")
    assert LobbyRestrictions.noob_title?("Newbies")
    assert LobbyRestrictions.noob_title?("New players")

    # Not noob titles
    refute LobbyRestrictions.noob_title?("No Noobs 1v1")
    refute LobbyRestrictions.noob_title?("No N00bz")
    refute LobbyRestrictions.noob_title?("No Newbz")
    refute LobbyRestrictions.noob_title?("No Newbies")
    refute LobbyRestrictions.noob_title?("No New players")
  end

  test "get title based on consul state rank filters" do
    result = LobbyRestrictions.get_rank_bounds_for_title(nil)
    assert result == nil

    result = LobbyRestrictions.get_rank_bounds_for_title(%{})
    assert result == nil

    result = LobbyRestrictions.get_rank_bounds_for_title(%{maximum_rank_to_play: 4})
    assert result == "Max chev: 5"

    result = LobbyRestrictions.get_rank_bounds_for_title(%{minimum_rank_to_play: 4})
    assert result == "Min chev: 5"
  end

  test "get title based on consul state rating filters" do
    result = LobbyRestrictions.get_rating_bounds_for_title(nil)
    assert result == nil

    result = LobbyRestrictions.get_rating_bounds_for_title(%{})
    assert result == nil

    result = LobbyRestrictions.get_rating_bounds_for_title(%{maximum_rating_to_play: 4})
    assert result == "Max rating: 4"

    result = LobbyRestrictions.get_rating_bounds_for_title(%{minimum_rating_to_play: 4})
    assert result == "Min rating: 4"

    result =
      LobbyRestrictions.get_rating_bounds_for_title(%{
        minimum_rating_to_play: 4,
        maximum_rating_to_play: 20
      })

    assert result == "Rating: 4-20"
  end
end
