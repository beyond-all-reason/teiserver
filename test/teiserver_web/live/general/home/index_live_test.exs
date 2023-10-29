defmodule TeiserverWeb.General.Home.IndexLiveTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest

  defp auth_setup(_) do
    Central.Helpers.GeneralTestLib.conn_setup()
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  describe "Anon" do
    test "index", %{conn: conn} do
      {:error, {:redirect, resp}} = live(conn, ~p"/")
      assert resp == %{flash: %{"error" => "You must log in to access this page."}, to: ~p"/login"}
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
