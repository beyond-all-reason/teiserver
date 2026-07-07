defmodule TeiserverWeb.Moderation.BannedDomainLiveTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.ModerationFixtures

  @update_attrs %{domain: "some updated domain"}
  @invalid_attrs %{domain: nil}

  describe "Index" do
    setup [:auth, :create_banned_domain]

    test "lists all banned_domains", %{conn: conn, banned_domain: banned_domain} do
      {:ok, _index_live, html} = live(conn, ~p"/moderation/banned_domains")

      assert html =~ "Listing banned domains"
      assert html =~ banned_domain.domain
    end

    test "saves banned_domain", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert {:ok, form_live, _html} =
               index_live
               |> element(~s{a[href="/moderation/banned_domains/new"]})
               |> render_click()
               |> follow_redirect(conn, ~p"/moderation/banned_domains/new")

      assert render(form_live) =~ "New Banned domain"

      assert form_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#banned_domain-form", banned_domain: %{domain: "some domain abcdef"})
               |> render_submit()
               |> follow_redirect(conn, ~p"/moderation/banned_domains")

      html = render(index_live)
      assert html =~ "Banned domain created successfully"
      assert html =~ "some domain abcdef"
    end

    test "updates banned_domain in listing", %{conn: conn, banned_domain: banned_domain} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert {:ok, form_live, _html} =
               index_live
               |> element("#banned_domains-#{banned_domain.id} a", "Edit")
               |> render_click()
               |> follow_redirect(conn, ~p"/moderation/banned_domains/#{banned_domain}/edit")

      assert render(form_live) =~ "Edit Banned domain"

      assert form_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, index_live, _html} =
               form_live
               |> form("#banned_domain-form", banned_domain: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/moderation/banned_domains")

      html = render(index_live)
      assert html =~ "Banned domain updated successfully"
      assert html =~ "some updated domain"
    end

    test "deletes banned_domain in listing", %{conn: conn, banned_domain: banned_domain} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert index_live
             |> element("#banned_domains-#{banned_domain.id} a", "Delete")
             |> render_click()

      refute has_element?(index_live, "#banned_domains-#{banned_domain.id}")
    end
  end

  describe "Show" do
    setup [:auth, :create_banned_domain]

    test "displays banned_domain", %{conn: conn, banned_domain: banned_domain} do
      {:ok, _show_live, html} = live(conn, ~p"/moderation/banned_domains/#{banned_domain}")

      assert html =~ banned_domain.domain
    end

    test "updates banned_domain and returns to show", %{conn: conn, banned_domain: banned_domain} do
      {:ok, show_live, _html} = live(conn, ~p"/moderation/banned_domains/#{banned_domain}")

      assert {:ok, form_live, _html} =
               show_live
               |> element("a", "Edit")
               |> render_click()
               |> follow_redirect(
                 conn,
                 ~p"/moderation/banned_domains/#{banned_domain}/edit?return_to=show"
               )

      assert render(form_live) =~ "Edit Banned domain"

      assert form_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert {:ok, show_live, _html} =
               form_live
               |> form("#banned_domain-form", banned_domain: @update_attrs)
               |> render_submit()
               |> follow_redirect(conn, ~p"/moderation/banned_domains/#{banned_domain}")

      html = render(show_live)
      assert html =~ "Banned domain updated successfully"
      assert html =~ "some updated domain"
    end
  end

  defp create_banned_domain(_state) do
    banned_domain = banned_domain_fixture()
    %{banned_domain: banned_domain}
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
