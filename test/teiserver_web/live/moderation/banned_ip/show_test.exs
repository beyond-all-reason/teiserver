defmodule TeiserverWeb.Moderation.BannedIPLive.ShowTest do
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.ModerationFixtures

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/banned_ips/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Overwatch"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/moderation/banned_ips/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      banned_ip = ModerationFixtures.banned_ip_fixture()

      {:ok, _live, _html} = live(conn, ~p"/moderation/banned_ips/#{banned_ip.id}")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    @tag :needs_attention
    test "redirect on no ip", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/moderation/banned_ips/list",
          flash: _flash
        }}} =
        live(conn, ~p"/moderation/banned_ips/123456789")
    end

    test "render ip", %{conn: conn} do
      banned_ip = ModerationFixtures.banned_ip_fixture()

      {:ok, _live, html} = live(conn, ~p"/moderation/banned_ips/#{banned_ip.id}")

      assert html =~ ~s(Banned IP: #{banned_ip.cidr})
    end
  end

  defp auth(_state) do
    TeiserverTestLib.moderator_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
