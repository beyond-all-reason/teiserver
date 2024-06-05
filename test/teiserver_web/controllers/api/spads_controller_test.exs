defmodule TeiserverWeb.API.SpadsControllerTest do
  use TeiserverWeb.ConnCase, async: false
  alias Teiserver.Account
  alias Teiserver.Lobby
  alias Teiserver.Game.MatchRatingLib
  alias Teiserver.{Coordinator, User}
  alias Teiserver.Account.ClientLib

  import Teiserver.TeiserverTestLib,
    only: [
      tachyon_auth_setup: 0,
      _tachyon_send: 2,
      _tachyon_recv: 1,
      tachyon_auth_setup: 1,
      new_user: 0,
      new_user: 1
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

    @tag :needs_attention
    test "existing user", %{conn: conn} do
      user = new_user()
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

    @tag :needs_attention
    test "good data", %{conn: conn} do
      Coordinator.start_coordinator()
      %{socket: hsocket, user: host} = tachyon_auth_setup()

      # User needs to be a moderator (at this time) to start/stop Coordinator mode
      User.update_user(%{host | moderator: true})
      ClientLib.refresh_client(host.id)

      lobby_data = %{
        cmd: "c.lobby.create",
        name: "Coordinator #{:rand.uniform(999_999_999)}",
        nattype: "none",
        port: 1234,
        game_hash: "string_of_characters",
        map_hash: "string_of_characters",
        map_name: "koom valley",
        game_name: "BAR",
        engine_name: "spring-105",
        engine_version: "105.1.2.3",
        settings: %{
          max_players: 16
        }
      }

      _tachyon_send(hsocket, %{cmd: "c.lobby.create", lobby: lobby_data})
      [reply] = _tachyon_recv(hsocket)
      lobby_id = reply["lobby"]["id"]

      # Player needs to be added to the battle
      %{user: u1} = ps1 = new_user("Auger") |> tachyon_auth_setup()
      %{user: u2} = ps2 = new_user("Basilica") |> tachyon_auth_setup()
      %{user: u3} = ps3 = new_user("Crossbow") |> tachyon_auth_setup()
      %{user: u4} = ps4 = new_user("Dagger") |> tachyon_auth_setup()

      rating_type_id = MatchRatingLib.rating_type_name_lookup()["Team"]

      [ps1, ps2, ps3, ps4]
      |> Enum.each(fn %{user: user, socket: socket} ->
        Lobby.force_add_user_to_lobby(user.id, lobby_id)
        # Need the sleep to ensure they all get added to the battle
        :timer.sleep(50)

        _tachyon_send(socket, %{
          cmd: "c.lobby.update_status",
          client: %{player: true, ready: true}
        })
      end)

      # Create some ratings
      # higher numbered players have higher ratings
      make_rating(u1.id, rating_type_id, 20)
      make_rating(u2.id, rating_type_id, 25)
      make_rating(u3.id, rating_type_id, 30)
      make_rating(u4.id, rating_type_id, 35)

      params = %{
        "bots" => "{}",
        "nbTeams" => "2",
        "players" =>
          "{'Auger': {'skill': 19.57, 'color': {'blue': 13, 'red': 185, 'green': 87}, 'sigma': 8.07, 'battleStatus': {'ready': 1, 'bonus': 0, 'id': 1, 'side': 0, 'sync': 1, 'team': 0, 'mode': 1}, 'ip': None, 'scriptPass': '---pass---', 'port': None}, 'Basilica': {'scriptPass': '---pass---', 'port': None, 'skill': 27.47, 'color': {'blue': 0, 'red': 255, 'green': 0}, 'ip': None, 'battleStatus': {'mode': 1, 'team': 0, 'sync': 1, 'id': 0, 'side': 1, 'ready': 0, 'bonus': 0}, 'sigma': 5.11}, 'Crossbow': {'skill': 19.57, 'color': {'blue': 13, 'red': 185, 'green': 87}, 'sigma': 8.07, 'battleStatus': {'ready': 1, 'bonus': 0, 'id': 1, 'side': 0, 'sync': 1, 'team': 0, 'mode': 1}, 'ip': None, 'scriptPass': '---pass---', 'port': None}, 'Dagger': {'scriptPass': '---pass---', 'port': None, 'skill': 27.47, 'color': {'blue': 0, 'red': 255, 'green': 0}, 'ip': None, 'battleStatus': {'mode': 1, 'team': 0, 'sync': 1, 'id': 0, 'side': 1, 'ready': 0, 'bonus': 0}, 'sigma': 5.11}}",
        "teamSize" => "1.0"
      }

      conn = get(conn, Routes.ts_spads_path(conn, :balance_battle, params))
      response = response(conn, 200)
      data = Jason.decode!(response)

      # Due to fuzzing of values we can see the imbalance indicator change
      # It can go as high as 2
      assert Enum.member?([2, 1, 0], data["unbalance_indicator"])
      assert Map.keys(data["player_assign_hash"]) == ["Auger", "Basilica", "Crossbow", "Dagger"]
    end
  end
end
