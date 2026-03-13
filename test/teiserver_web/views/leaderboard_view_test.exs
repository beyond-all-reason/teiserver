defmodule TeiserverWeb.LeaderboardTest do
  alias Teiserver.CacheUser
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib, Lobby}
  import Teiserver.TeiserverTestLib, only: [_send_raw: 2, _recv_until: 1]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "tournament live" do
    test "index", %{conn: conn, user: user} do
      {:ok, view, html} = get(conn, "/battle/ratings/leaderboard")
      assert view != nil
      assert html =~ "Leader"
    end
  end
end
