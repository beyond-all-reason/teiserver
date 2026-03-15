defmodule TeiserverWeb.BattleTest do
  use TeiserverWeb.ConnCase, async: true

  alias Central.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  describe "battle base path" do
    test "index" do
      {:ok, kw} =
        GeneralTestLib.conn_setup()
        |> TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)

      conn = get(conn, ~p"/battle")
      html_response(conn, 200)
    end
  end

  describe "tachyon lobbies do not yet appear for players" do
    test "index does not show option to switch to Tachyon Lobbies " do
      {:ok, kw} =
        GeneralTestLib.conn_setup(TeiserverTestLib.player_permissions())
        |> TeiserverTestLib.conn_setup()

      {:ok, conn} = Keyword.fetch(kw, :conn)

      html_string = conn.resp_body
      refute html_string =~ "Tachyon Lobbies"
    end
  end
end
