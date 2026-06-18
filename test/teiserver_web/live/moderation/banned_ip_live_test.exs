defmodule TeiserverWeb.BannedIPLiveTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  import Phoenix.LiveViewTest
  import Teiserver.ModerationFixtures

  @create_attrs %{cidr: "100.100.0.1/32"}
  @update_attrs %{cidr: "200.200.0.1/32"}
  @invalid_attrs %{cidr: nil}

  describe "Index" do
    setup [:auth, :create_banned_ip]

    test "lists all banned_ips", %{conn: conn, banned_ip: banned_ip} do
      {:ok, _index_live, html} = live(conn, ~p"/moderation/banned_ips")

      assert html =~ "Listing Banned ips"
      assert html =~ banned_ip.cidr
    end

    test "saves banned_ip", %{conn: conn} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("a", "banned ip") |> render_click() =~
               "Banned ip"

      assert_patch(index_live, ~p"/moderation/banned_ips/new")

      assert index_live
             |> form("#banned_ip-form", banned_ip: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_ip-form", banned_ip: @create_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_ips")

      html = render(index_live)
      assert html =~ "Banned ip created successfully"
      assert html =~ "100.100.0.1/32"
    end

    test "updates banned_ip in listing", %{conn: conn, banned_ip: banned_ip} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("#banned_ips-#{banned_ip.id} a", "Edit") |> render_click() =~
               "Edit Banned IP"

      assert_patch(index_live, ~p"/moderation/banned_ips/#{banned_ip}/edit")

      assert index_live
             |> form("#banned_ip-form", banned_ip: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert index_live
             |> form("#banned_ip-form", banned_ip: @update_attrs)
             |> render_submit()

      assert_patch(index_live, ~p"/moderation/banned_ips")

      html = render(index_live)
      assert html =~ "Banned ip updated successfully"
      assert html =~ "200.200.0.1/32"
    end

    test "deletes banned_ip in listing", %{conn: conn, banned_ip: banned_ip} do
      {:ok, index_live, _html} = live(conn, ~p"/moderation/banned_ips")

      assert index_live |> element("#banned_ips-#{banned_ip.id} a", "Delete") |> render_click()
      refute has_element?(index_live, "#banned_ips-#{banned_ip.id}")
    end
  end

  describe "Show" do
    setup [:auth, :create_banned_ip]

    test "displays banned_ip", %{conn: conn, banned_ip: banned_ip} do
      {:ok, _show_live, html} = live(conn, ~p"/moderation/banned_ips/#{banned_ip}")

      assert html =~ "Show banned ip"
      assert html =~ banned_ip.cidr
    end

    test "updates banned_ip within modal", %{conn: conn, banned_ip: banned_ip} do
      {:ok, show_live, _html} = live(conn, ~p"/moderation/banned_ips/#{banned_ip}")

      assert show_live |> element("a", "Edit") |> render_click() =~
               "Edit banned ip"

      assert_patch(show_live, ~p"/moderation/banned_ips/#{banned_ip}/show/edit")

      assert show_live
             |> form("#banned_ip-form", banned_ip: @invalid_attrs)
             |> render_change() =~ "can&#39;t be blank"

      assert show_live
             |> form("#banned_ip-form", banned_ip: @update_attrs)
             |> render_submit()

      assert_patch(show_live, ~p"/moderation/banned_ips/#{banned_ip}")

      html = render(show_live)
      assert html =~ "Banned ip updated successfully"
      assert html =~ "200.200.0.1/32"
    end
  end

  defp create_banned_ip(_state) do
    banned_ip = banned_ip_fixture()
    %{banned_ip: banned_ip}
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
