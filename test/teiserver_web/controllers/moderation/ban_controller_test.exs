defmodule TeiserverWeb.Moderation.BanControllerTest do
  @moduledoc false
  use CentralWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.Moderation.ModerationTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([
      "teiserver.staff.overwatch",
      "teiserver.staff.reviewer",
      "teiserver.staff.moderator"
    ])
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{"key_values" => ["key1", "key2"], "enabled" => true, "reason" => "reason"}
  @invalid_attrs %{"key_values" => []}

  describe "index" do
    test "lists all bans", %{conn: conn} do
      conn = get(conn, Routes.moderation_ban_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Bans"
    end
  end

  describe "new ban" do
    test "renders select form", %{conn: conn} do
      conn = get(conn, Routes.moderation_ban_path(conn, :new))
      assert html_response(conn, 200) =~ "Select user:"
    end

    test "renders creation form", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        get(
          conn,
          Routes.moderation_ban_path(conn, :new_with_user) <> "?teiserver_user=%23#{user.id}"
        )

      assert html_response(conn, 200) =~ "Adding ban based on"
    end
  end

  describe "create ban" do
    test "redirects to show when data is valid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.moderation_ban_path(conn, :create),
          ban:
            Map.merge(@create_attrs, %{
              source_id: user.id
            })
        )

      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)

      new_ban = Moderation.list_bans(search: [source_id: user.id])
      assert Enum.count(new_ban) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.moderation_ban_path(conn, :create),
          ban: Map.merge(@invalid_attrs, %{source_id: user.id})
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show ban" do
    test "renders show page", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      resp = get(conn, Routes.moderation_ban_path(conn, :show, ban))
      assert html_response(resp, 200) =~ "Logs (0)"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_ban_path(conn, :show, -1))
      end
    end
  end

  describe "update ban" do
    test "enable/disable", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()

      assert ban.enabled == true

      conn = put(conn, Routes.moderation_ban_path(conn, :disable, ban.id))
      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)

      ban = Moderation.get_ban!(ban.id)
      assert ban.enabled == false

      conn = put(conn, Routes.moderation_ban_path(conn, :enable, ban.id))
      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)

      ban = Moderation.get_ban!(ban.id)
      assert ban.enabled == true
    end
  end
end
