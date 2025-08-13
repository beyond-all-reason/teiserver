defmodule TeiserverWeb.Admin.MatchmakingLive.IndexTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "cannot access admin matchmaking without authenticating" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/matchmaking")
    assert redirected_to(conn) == ~p"/login"
  end

  test "cannot access admin matchmaking when unauthorized" do
    {:ok, kw} = GeneralTestLib.conn_setup()
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/matchmaking")
    assert redirected_to(conn) == ~p"/"
  end

  test "can access admin matchmaking when authorized" do
    {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/matchmaking")
    html_response(conn, 200)
  end

  test "displays queue stats table structure" do
    {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
    {:ok, conn} = Keyword.fetch(kw, :conn)

    # Access the admin page
    conn = get(conn, ~p"/admin/matchmaking")
    html = html_response(conn, 200)

    # Verify the page contains the expected table headers
    assert html =~ "Queue ID"
    assert html =~ "Name"
    assert html =~ "Team Size"
    assert html =~ "Team Count"
    assert html =~ "Total Players"
    assert html =~ "Total Joined"
    assert html =~ "Total Left"
    assert html =~ "Total Matched"
    assert html =~ "Total Wait Time (s)"

    # Verify the page contains the matchmaking queues section
    assert html =~ "Matchmaking Queues"
  end
end
