defmodule TeiserverWeb.Admin.SiteConfigLive.ShowTest do
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  @key "teiserver.Default player limit"

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/site_config/#{@key}/history")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/site_config/#{@key}/history")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:ok, _live, _html} = live(conn, ~p"/admin/site_config/#{@key}/history")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "render site config", %{conn: conn} do
      {:ok, _live, html} = live(conn, ~p"/admin/site_config/#{@key}/history")

      assert html =~ ~s(Default player limit)
      assert html =~ ~s(The default player limit for lobbies)
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
