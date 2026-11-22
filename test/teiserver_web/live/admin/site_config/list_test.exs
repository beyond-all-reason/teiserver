defmodule TeiserverWeb.Admin.SiteConfigLive.ListTest do
  alias Teiserver.Account
  alias Teiserver.Helper.StringHelper
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: false

  @key "teiserver.Default player limit"
  @safe_key StringHelper.safe_name(@key)

  describe "access control" do
    test "cannot access list page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/site_config")
      assert path == ~p"/login"
    end

    test "cannot access list page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:error, {:redirect, %{to: path}}} = live(conn, ~p"/admin/site_config")
      assert path == ~p"/"
    end

    test "can access list page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      {:ok, live, _html} = live(conn, ~p"/admin/site_config")

      assert has_element?(live, "#site_config-table")
    end
  end

  describe "rendering data" do
    setup [:auth]

    test "listing data", %{conn: conn} do
      {:ok, live, _html} = live(conn, ~p"/admin/site_config")

      table_html =
        live
        |> element("table")
        |> render()

      # Two setting types we expect to exist
      assert table_html =~ "Automod action delay"
      assert table_html =~ "Post login action delay"

      # Now pop something in the search field
      live
      |> render_change("update-search", %{"name" => "post"})

      table_html =
        live
        |> element("table")
        |> render()

      refute table_html =~ "Automod action delay"
      assert table_html =~ "Post login action delay"
    end
  end

  describe "changing data" do
    setup [:auth]

    test "an admin can correct an invalid login rate in the same form", %{conn: conn} do
      key = "system.Login rate"
      previous_rate = Config.get_site_config_cache(key)
      on_exit(fn -> Account.reset_login_rate_limiter(previous_rate) end)

      {:ok, live, _html} = live(conn, ~p"/admin/site_config/#{key}/edit")

      assert live
             |> form("#site_config-form", value: "-1")
             |> render_submit() =~ "must be a non-negative integer"

      assert Config.get_site_config_cache(key) == previous_rate

      live
      |> form("#site_config-form", value: "0")
      |> render_submit()

      assert_patch(live, ~p"/admin/site_config")
      assert Config.get_site_config(key).value == "0"
    end

    test "updates site_config in listing", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/admin/site_config")

      assert index_live
             |> element("#row-#{@safe_key} a", "Edit")
             |> render_click() =~
               "The default player limit for lobbies"

      assert_patch(index_live, ~p"/admin/site_config/#{@key}/edit")

      assert index_live
             |> form("#site_config-form", value: "123456789111")
             |> render_submit()

      assert_patch(index_live, ~p"/admin/site_config")

      html = render(index_live)
      assert html =~ "Site config updated successfully"
      assert html =~ "123456789111"
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
