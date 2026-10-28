defmodule TeiserverWeb.Admin.DiscordChannelLive.ShowTest do
  alias Teiserver.Communication
  alias Teiserver.CommunicationFixtures
  alias Teiserver.Helpers.GeneralTestLib

  use TeiserverWeb.ConnCase, async: true

  describe "access control" do
    test "cannot access show page without authenticating" do
      {:ok, kw} = GeneralTestLib.conn_setup([], [:no_login])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/discord_channels/123")

      assert path == ~p"/login"
    end

    test "cannot access show page when unauthorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Moderator"])
      {:ok, conn} = Keyword.fetch(kw, :conn)

      {:error, {:redirect, %{to: path}}} =
        live(conn, ~p"/admin/discord_channels/123")

      assert path == ~p"/"
    end

    test "can access show page when authorized" do
      {:ok, kw} = GeneralTestLib.conn_setup(["Admin"])
      {:ok, conn} = Keyword.fetch(kw, :conn)
      discord_channel = CommunicationFixtures.discord_channel_fixture()

      {:ok, _live, _html} = live(conn, ~p"/admin/discord_channels/#{discord_channel.id}")
    end
  end

  describe "rendering data" do
    setup [:auth]

    # For reasons unknown this test fails despite being made by the generator
    # at this stage I'm happy for it to fail and address it later, might be
    # the newer version of phoenix solves it and we're trying to do things
    # across two different versions
    @tag :needs_attention
    test "redirect on no discord channel", %{conn: conn} do
      {:error,
       {:redirect,
        %{
          status: 302,
          to: "/admin/discord_channels/list",
          flash: _flash
        }}} =
        live(conn, ~p"/admin/discord_channels/123456789")
    end

    test "render discord channel", %{conn: conn} do
      discord_channel = CommunicationFixtures.discord_channel_fixture()

      {:ok, _live, html} = live(conn, ~p"/admin/discord_channels/#{discord_channel.id}")

      assert html =~ ~s(Discord channel: #{discord_channel.name})
    end
  end

  describe "deleting data" do
    setup [:auth]

    test "deletes discord_channel", %{conn: conn} do
      discord_channel = CommunicationFixtures.discord_channel_fixture()
      {:ok, live, _html} = live(conn, ~p"/admin/discord_channels/#{discord_channel.id}")

      assert live |> element(".btn-error", "Delete") |> render_click()

      refute Communication.get_discord_channel(discord_channel.id)

      assert_redirect(live, "/admin/discord_channels")
    end
  end

  defp auth(_state) do
    TeiserverTestLib.admin_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end
end
