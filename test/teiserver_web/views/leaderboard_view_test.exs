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
