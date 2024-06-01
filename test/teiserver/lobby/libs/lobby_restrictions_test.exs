defmodule Teiserver.Lobby.Libs.LobbyRestrictionsTest do
  @moduledoc false
  use Teiserver.ServerCase, async: false
  alias Teiserver.Lobby.LobbyRestrictions

  # test "raw call tests" do

  # end

  test "check for noob title" do
    result = LobbyRestrictions.is_noob_title?("Noobs 1v1")
    assert result == true

    result = LobbyRestrictions.is_noob_title?("No Noobs 1v1")
    assert result == false

    result = LobbyRestrictions.is_noob_title?("All Welcome 1v1")
    assert result == false

    result = LobbyRestrictions.is_noob_title?("Newbies 1v1")
    assert result == true

    result = LobbyRestrictions.is_noob_title?("Nubs 1v1")
    assert result == true

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

    result = LobbyRestrictions.get_rating_bounds_for_title(%{minimum_rating_to_play: 4, maximum_rating_to_play: 20})
    assert result ==  "Rating between: 4 - 20"
  end
end
