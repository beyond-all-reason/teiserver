defmodule TeiserverWeb.Microblog.Blog.PreferenceLiveTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "microblog preferences requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/microblog/preferences")
    assert redirected_to(conn) == ~p"/login"
  end

  test "authenticated user can access microblog preferences" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [])
      |> Teiserver.TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/microblog/preferences")
    html_response(conn, 200)
  end
end
