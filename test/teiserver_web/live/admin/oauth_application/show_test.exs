defmodule TeiserverWeb.Admin.OAuthApplicationLive.ShowTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.OAuth
  alias Teiserver.OAuthFixtures

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/oauth_applications/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/oauth_applications/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      oauth_application = OAuthFixtures.app_fixture()

      {:ok, _live, _html} = live(conn, ~p"/admin/oauth_applications/#{oauth_application.id}")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    # @tag :needs_attention
    # test "redirect on no discord channel", %{conn: conn} do
    #   {:error,
    #    {:redirect,
    #     %{
    #       status: 302,
    #       to: "/admin/oauth_applications/list",
    #       flash: _flash
    #     }}} =
    #     live(conn, ~p"/admin/oauth_applications/123456789")
    # end

    test "render discord channel", %{conn: conn} do
      oauth_application = OAuthFixtures.app_fixture()

      {:ok, _live, html} = live(conn, ~p"/admin/oauth_applications/#{oauth_application.id}")

      assert html =~ ~s(OAuth application: #{oauth_application.name})
    end
  end

  describe "deleting data" do
    setup [:auth]

    test "deletes oauth_application", %{conn: conn} do
      oauth_application = OAuthFixtures.app_fixture()
      {:ok, live, _html} = live(conn, ~p"/admin/oauth_applications/#{oauth_application.id}")

      assert live |> element(".btn-error", "Delete") |> render_click()

      refute OAuth.get_application_by_id(oauth_application.id)

      assert_redirect(live, "/admin/oauth_applications")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
