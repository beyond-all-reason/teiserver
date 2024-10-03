defmodule TeiserverWeb.Communication.ChatLive.IndexLiveTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib

  test "cannot access chat without authenticating" do
    {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/chat")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access chat once authenticated" do
    {:ok, kw} = GeneralTestLib.conn_setup()
    {:ok, conn} = Keyword.fetch(kw, :conn)
    conn = get(conn, ~p"/chat")
    html_response(conn, 200)
  end
end
