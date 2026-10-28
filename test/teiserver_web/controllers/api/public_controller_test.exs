defmodule TeiserverWeb.API.PublicControllerTest do
  alias Teiserver.Config

  use TeiserverWeb.ConnCase, async: false

  describe "leaderboard" do
    test "season and game type list is public", %{conn: conn} do
      conn = get(conn, ~p"/teiserver/api/public/leaderboard/")
      assert response(conn, 200)
    end

    test "season leaderboard is public", %{conn: conn} do
      conn = get(conn, ~p"/teiserver/api/public/leaderboard/1")
      assert response(conn, 200)
    end

    test "lowest season is 1", %{conn: conn} do
      conn = get(conn, ~p"/teiserver/api/public/leaderboard/0")
      assert response(conn, 400)
    end

    test "can't get seasons above current season", %{conn: conn} do
      Config.update_site_config("rating.Season", 2)

      conn = get(conn, ~p"/teiserver/api/public/leaderboard/3")
      assert response(conn, 400)
    end
  end
end
