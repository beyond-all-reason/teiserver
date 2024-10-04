defmodule TeiserverWeb.General.Home.IndexLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest

  defp auth_setup(_) do
    Central.Helpers.GeneralTestLib.conn_setup()
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  describe "Visit index without authentication" do
    test "index get", %{conn: conn} do
      conn = get(conn, ~p"/")
      assert redirected_to(conn) == ~p"/login"
    end

    test "index live", %{conn: conn} do
      {:error, {:redirect, resp}} = live(conn, ~p"/")

      assert resp.to == ~p"/login"
    end
  end

  describe "Auth" do
    setup [:auth_setup]

    test "index", %{conn: conn} do
      {:ok, _index_live, html} = live(conn, ~p"/")

      assert html =~ "Logout"
      assert html =~ "Account"
    end
  end
end
