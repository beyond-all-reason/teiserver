defmodule TeiserverWeb.Battle.MatchLive.RatingsLiveTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "battle ratings endpoints requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/battle/ratings")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access battle ratings when authenticated" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/battle/ratings")
    html_response(conn, 200)
  end
end
