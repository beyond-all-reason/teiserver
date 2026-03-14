defmodule TeiserverWeb.Live.TachyonLobbyPlayerTest do
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "tachyon battle live" do
    test "players are not yet permitted to see tachyon lobbies", %{conn: conn, user: _user} do
      {:error, {:redirect, resp}} = live(conn, "/battle/tachyon_lobbies")
      assert resp.to == ~p"/"
    end

    test "index does not show option to switch to Tachyon Lobbies ", %{conn: conn, user: _user} do
      {:ok, _view, html} = live(conn, "/battle/lobbies")
      refute html =~ "Tachyon Lobbies"
    end
  end
end
