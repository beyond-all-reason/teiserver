defmodule TeiserverWeb.API.SpadsControllerTest do
  use CentralWeb.ConnCase
  alias Teiserver.Account
  alias Teiserver.Game.MatchRatingLib
  import Teiserver.TeiserverTestLib, only: [new_user: 0]

  describe "ratings" do
    test "non-user", %{conn: conn} do
      conn = get(conn, Routes.ts_spads_path(conn, :get_rating, -1, "Team"))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{"rating_value" => 16.67, "uncertainty" => 8.33}
    end

    test "existing user", %{conn: conn} do
      user = new_user()
      rating_type_id = MatchRatingLib.rating_type_name_lookup()["Team"]
      {:ok, _} = Account.create_rating(%{
        user_id: user.id,
        rating_type_id: rating_type_id,
        rating_value: 20,
        skill: 25,
        uncertainty: 5,
        leaderboard_rating: 5,
        last_updated: Timex.now(),
      })

      conn = get(conn, Routes.ts_spads_path(conn, :get_rating, user.id, "Team"))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{"rating_value" => 20, "uncertainty" => 5}
    end
  end
end
