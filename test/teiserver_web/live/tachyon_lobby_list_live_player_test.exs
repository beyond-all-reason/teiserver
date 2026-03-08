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
    # TODO correctly redirect to home
    test "index with no battles shows no lobbies found ", %{conn: conn, user: _user} do
      {:ok, _view, html} = live(conn, "/battle/tachyon_lobbies")
      refute html =~ "No lobbies found"
    end

    # TODO correctly verify that tachyon lobby sub_menu option does not appear for a regular player
    test "index does not show option to switch to Tachyon Lobbies ", %{conn: conn, user: _user} do
      {:ok, _view, html} = live(conn, "/battle/lobbies")
      refute html =~ "Tachyon Lobbies"
    end
  end
end
