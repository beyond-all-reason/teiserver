defmodule TeiserverWeb.Moderation.BanControllerTest do
  @moduledoc false

  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.Moderation
  alias Teiserver.Moderation.ModerationTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(["Reviewer", "Moderator", "Overwatch"])
    |> TeiserverTestLib.conn_setup()
  end

  @create_attrs %{"key_values" => ["key1", "key2"], "enabled" => true, "reason" => "reason"}
  @invalid_attrs %{"key_values" => []}

  describe "index" do
    test "lists all bans", %{conn: conn} do
      conn = get(conn, ~p"/moderation/ban")
      assert html_response(conn, 200) =~ "Listing Bans"
    end
  end

  describe "new ban" do
    test "renders select form", %{conn: conn} do
      conn = get(conn, ~p"/moderation/ban/new")
      assert html_response(conn, 200) =~ "Select user:"
    end

    test "renders creation form", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        get(
          conn,
          ~p"/moderation/ban/new_with_user?teiserver_user=%23#{user.id}"
        )

      assert html_response(conn, 200) =~ "Adding ban based on"
    end
  end

  describe "create ban" do
    test "redirects to show when data is valid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, ~p"/moderation/ban",
          ban:
            Map.merge(@create_attrs, %{
              source_id: user.id
            })
        )

      assert redirected_to(conn) == ~p"/moderation/ban"

      new_ban = Moderation.list_bans(search: [source_id: user.id])
      assert Enum.count(new_ban) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, ~p"/moderation/ban",
          ban: Map.merge(@invalid_attrs, %{source_id: user.id})
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show ban" do
    test "renders show page", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      resp = get(conn, ~p"/moderation/ban/#{ban.id}")
      assert html_response(resp, 200) =~ "Logs (0)"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/moderation/ban/-1")
      end
    end
  end

  describe "update ban" do
    test "enable/disable", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()

      assert ban.enabled == true

      conn = put(conn, ~p"/moderation/ban/#{ban.id}/disable")
      assert redirected_to(conn) == ~p"/moderation/ban"

      ban = Moderation.get_ban!(ban.id)
      assert ban.enabled == false

      conn = put(conn, ~p"/moderation/ban/#{ban.id}/enable")
      assert redirected_to(conn) == ~p"/moderation/ban"

      ban = Moderation.get_ban!(ban.id)
      assert ban.enabled == true
    end
  end
end
