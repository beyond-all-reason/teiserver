defmodule TeiserverWeb.API.SpadsControllerTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Account
  alias Teiserver.Lobby
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.Coordinator
  alias Teiserver.Account.ClientLib
  alias Teiserver.Client
  alias TeiserverWeb.API.SpadsController

  import Teiserver.TeiserverTestLib,
    only: [
      new_user: 0,
      new_user: 1,
      make_lobby: 1
    ]

  defp make_rating(userid, rating_type_id, rating_value) do
    {:ok, _} =
      Account.create_rating(%{
        user_id: userid,
        rating_type_id: rating_type_id,
        rating_value: rating_value,
        skill: rating_value,
        uncertainty: 0,
        leaderboard_rating: rating_value,
        last_updated: Timex.now()
      })
  end

  describe "ratings" do
    test "non-user", %{conn: conn} do
      conn = get(conn, Routes.ts_spads_path(conn, :get_rating, -1, "Team"))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{"rating_value" => 16.67, "uncertainty" => 8.33}
    end

    test "existing user", %{conn: conn} do
      user = new_user()
      Teiserver.TeiserverTestLib.clear_cache(:teiserver_game_rating_types)
      rating_type_id = MatchRatingLib.rating_type_name_lookup()["Team"]

      {:ok, _} =
        Account.create_rating(%{
          user_id: user.id,
          rating_type_id: rating_type_id,
          rating_value: 20,
          skill: 25,
          uncertainty: 5,
          leaderboard_rating: 5,
          last_updated: Timex.now()
        })

      Client.login(user, :spring, "127.0.0.1")

      lobby_id =
        make_lobby(%{name: "Test", founder_id: user.id, founder_name: user.name})

      Client.join_battle(user.id, lobby_id, true)

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
      params = %{
        "bots" =>
          "{'BARbarianAI(1)': {'color': {'red': 243, 'blue': 0, 'green': 0}, 'skill': 20, 'battleStatus': {'team': 0, 'mode': 1, 'bonus': 0, 'ready': 1, 'side': 0, 'sync': 1, 'id': 2}, 'aiDll': 'BARb', 'owner': 'Teifion'}}",
        "nbTeams" => "2",
        "players" =>
          "{'BEANS': {'scriptPass': '123', 'port': None, 'skill': 16.67, 'color': {'blue': 255, 'red': 0, 'green': 85}, 'ip': None, 'battleStatus': {'ready': 1, 'bonus': 0, 'id': 1, 'side': 0, 'sync': 1, 'workaroundId': 1, 'team': 1, 'mode': 1, 'workaroundTeam': 1}, 'sigma': 8.33}, 'Teifion': {'port': None, 'scriptPass': '5232537262', 'sigma': 4.07, 'ip': None, 'battleStatus': {'mode': 1, 'team': 0, 'workaroundId': 0, 'side': 1, 'sync': 1, 'id': 0, 'bonus': 0, 'ready': 0}, 'skill': 27.65, 'color': {'green': 0, 'blue': 0, 'red': 255}}}",
        "teamSize" => "2.0"
      }

      conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
      response = response(conn, 200)
      data = Jason.decode!(response)

      assert data == %{}
    end

    test "can detect empty balance result" do
      # This is the default balance result when no players
      # Defined inside balance_lib.ex
      balance_result = %{
        logs: [],
        time_taken: 0,
        captains: %{},
        deviation: 0,
        ratings: %{},
        team_groups: %{},
        team_players: %{},
        team_sizes: %{},
        means: %{},
        stdevs: %{},
        has_parties?: false
      }

      assert SpadsController.is_non_empty_balance_result?(balance_result) == false
    end
  end
end
