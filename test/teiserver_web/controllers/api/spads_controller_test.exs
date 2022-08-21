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

  describe "balance" do
    test "empty data", %{conn: conn} do
      params = %{"bots" => "{}", "players" => "{}"}

      conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{}
    end

    test "bad decode", %{conn: conn} do
      params = %{"bots" => "{}", "players" => "{123 - 123}"}

      conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{}
    end

    test "bots", %{conn: conn} do
      params = %{"bots" => "{'BARbarianAI(1)': {'color': {'red': 243, 'blue': 0, 'green': 0}, 'skill': 20, 'battleStatus': {'team': 0, 'mode': 1, 'bonus': 0, 'ready': 1, 'side': 0, 'sync': 1, 'id': 2}, 'aiDll': 'BARb', 'owner': 'Teifion'}}", "nbTeams" => "2", "players" => "{'BEANS': {'scriptPass': '123', 'port': None, 'skill': 16.67, 'color': {'blue': 255, 'red': 0, 'green': 85}, 'ip': None, 'battleStatus': {'ready': 1, 'bonus': 0, 'id': 1, 'side': 0, 'sync': 1, 'workaroundId': 1, 'team': 1, 'mode': 1, 'workaroundTeam': 1}, 'sigma': 8.33}, 'Teifion': {'port': None, 'scriptPass': '5232537262', 'sigma': 4.07, 'ip': None, 'battleStatus': {'mode': 1, 'team': 0, 'workaroundId': 0, 'side': 1, 'sync': 1, 'id': 0, 'bonus': 0, 'ready': 0}, 'skill': 27.65, 'color': {'green': 0, 'blue': 0, 'red': 255}}}", "teamSize" => "2.0"}

      conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{}
    end

    # Currently breaks because there's no lobby
    # test "good data", %{conn: conn} do
    #   params = %{"bots" => "{}", "nbTeams" => "2", "players" => "{'BEANS': {'skill': 19.57, 'color': {'blue': 13, 'red': 185, 'green': 87}, 'sigma': 8.07, 'battleStatus': {'ready': 1, 'bonus': 0, 'id': 1, 'side': 0, 'sync': 1, 'team': 0, 'mode': 1}, 'ip': None, 'scriptPass': 'GE3DAN3FHA3DMLJSGEZTGLJRGFSWILJZHA2WILJQGAYTMM3DMU2TCNDFGQ', 'port': None}, 'Teifion': {'scriptPass': '5232537262', 'port': None, 'skill': 27.47, 'color': {'blue': 0, 'red': 255, 'green': 0}, 'ip': None, 'battleStatus': {'mode': 1, 'team': 0, 'sync': 1, 'id': 0, 'side': 1, 'ready': 0, 'bonus': 0}, 'sigma': 5.11}}", "teamSize" => "1.0"}

    #   conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
    #   response = response(conn, 200)
    #   data = Jason.decode!(response)

    #   assert data == %{}
    # end
  end
end
