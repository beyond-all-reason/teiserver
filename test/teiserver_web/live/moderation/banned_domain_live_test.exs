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

      assert index_live |> element("a", "New banned domain") |> render_click() =~
               "banned domain"

      assert_patch(index_live, ~p"/moderation/banned_domains/new")

      assert index_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_domain-form", banned_domain: %{domain: "a new domain"})
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_domains")

      html = render(index_live)
      assert html =~ "Banned domain created successfully"
      assert html =~ "some domain"
    end

    test "updates banned_domain in listing", %{conn: conn, banned_domain: banned_domain} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_domains")

      assert index_live
             |> element("#banned_domains-#{banned_domain.id} a", "Edit")
             |> render_click() =~
               "Edit banned domain"

      assert_patch(index_live, ~p"/moderation/banned_domains/#{banned_domain}/edit")

      assert index_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_domain-form", banned_domain: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_domains")

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

      assert html =~ "Show banned domain"
      assert html =~ banned_domain.domain
    end

    test "updates banned_domain within modal", %{conn: conn, banned_domain: banned_domain} do
      {:ok, show_live, _html} = live(conn, ~p"/moderation/banned_domains/#{banned_domain}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit banned domain"

      assert_patch(show_live, ~p"/moderation/banned_domains/#{banned_domain}/show/edit")

      assert show_live
             |> form("#banned_domain-form", banned_domain: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#banned_domain-form", banned_domain: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/moderation/banned_domains/#{banned_domain}")

      html = render(show_live)
      assert html =~ "Banned domain updated successfully"
      assert html =~ "some updated domain"
    end
  end

  defp create_banned_domain(state) do
    banned_domain = banned_domain_fixture()
    Map.put(state, :banned_domain, banned_domain)
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
