defmodule TeiserverWeb.Live.PartyTest do
  alias Teiserver.CacheUser
  use TeiserverWeb.ConnCase, async: false
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib, Lobby}
  import Teiserver.TeiserverTestLib, only: [_send_raw: 2, _recv_until: 1]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "party live" do
    test "index", %{conn: conn, user: user} do
      {:ok, view, html} = live(conn, "/account/parties")
      assert view != nil
      assert html =~ "No lobbies found"
    end
  end
end
