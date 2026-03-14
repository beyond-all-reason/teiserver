defmodule TeiserverWeb.LeaderboardTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "tournament live" do
    test "index" do
      {:ok, kw} =
        GeneralTestLib.conn_setup()
        |> Teiserver.TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)

      conn = get(conn, ~p"/battle/ratings/leaderboard")
      html_response(conn, 200)
    end
  end
end
