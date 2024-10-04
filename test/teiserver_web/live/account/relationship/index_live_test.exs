defmodule TeiserverWeb.Account.RelationshipLive.IndexLiveTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "account relationship endpoints requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/relationship")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access account relationship when authenticated" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/relationship")
    html_response(conn, 200)
  end
end
