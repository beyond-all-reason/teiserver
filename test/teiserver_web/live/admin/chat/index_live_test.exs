defmodule TeiserverWeb.Admin.ChatLive.IndexLiveTest do
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  test "cannot access admin chat without authenticating" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/chat")
    assert redirected_to(conn) == ~p"/login"
  end

  test "cannot access admin chat when unauthorized" do
    {:ok, kw} = GeneralTestLib.conn_setup()
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/chat")
    assert redirected_to(conn) == ~p"/"
  end

  test "can access admin chat when authorized" do
    {:ok, kw} = GeneralTestLib.conn_setup(["Reviewer"])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/admin/chat")
    html_response(conn, 200)
  end
end
