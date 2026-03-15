defmodule TeiserverWeb.Live.PartyTest do
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "party live" do
    test "index", %{conn: conn, user: _user} do
      {:ok, view, html} = live(conn, "/teiserver/account/parties")
      assert view != nil
      assert html =~ "Connect with client to enable"
      assert html =~ "Parties"
    end
  end
end
