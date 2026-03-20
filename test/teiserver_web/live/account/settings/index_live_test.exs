defmodule TeiserverWeb.Account.SettingsLive.IndexLiveTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase, async: true

  test "account settings endpoints requires authentication" do
    {:ok, kw} =
      GeneralTestLib.conn_setup([], [:no_login])
      |> TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/settings")
    assert redirected_to(conn) == ~p"/login"
  end

  test "can access account settings when authenticated" do
    {:ok, kw} =
      GeneralTestLib.conn_setup()
      |> TeiserverTestLib.conn_setup()

    {:ok, conn} = Keyword.fetch(kw, :conn)

    conn = get(conn, ~p"/account/settings")
    html_response(conn, 200)
  end
end
