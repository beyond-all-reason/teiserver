defmodule TeiserverWeb.BattleTest do
  alias Teiserver.CacheUser
  use TeiserverWeb.ConnCase, async: true
  import Phoenix.LiveViewTest

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.{TeiserverTestLib, Lobby}
  import Teiserver.TeiserverTestLib, only: [_send_raw: 2, _recv_until: 1]
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "battle base path" do
    test "index" do
      {:ok, kw} =
        GeneralTestLib.conn_setup()
        |> Teiserver.TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)

      conn = get(conn, ~p"/battle")
      html_response(conn, 200)
    end
  end

  describe "tachyon lobbies do not yet appear for players" do
    test "index does not show option to switch to Tachyon Lobbies " do
      {:ok, kw} =
      GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.player_permissions())
      |> TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)

      html_string =   conn.resp_body
      refute html_string =~ "Tachyon Lobbies"

    end
  end
end
