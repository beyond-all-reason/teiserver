defmodule TeiserverWeb.Moderation.BanControllerTest do
  @moduledoc false
  use CentralWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.ModerationTestLib

  alias Central.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all bans", %{conn: conn} do
      conn = get(conn, Routes.moderation_ban_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Bans"
    end
  end

  describe "new ban" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.moderation_ban_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create ban" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.moderation_ban_path(conn, :create), ban: @create_attrs)
      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)

      new_ban = Moderation.list_bans(search: [name: @create_attrs.name])
      assert Enum.count(new_ban) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.moderation_ban_path(conn, :create), ban: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show ban" do
    test "renders show page", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      resp = get(conn, Routes.moderation_ban_path(conn, :show, ban))
      assert html_response(resp, 200) =~ "Edit ban"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_ban_path(conn, :show, -1))
      end
    end
  end

  describe "edit ban" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_ban_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen ban", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      conn = get(conn, Routes.moderation_ban_path(conn, :edit, ban))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update ban" do
    test "redirects when data is valid", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      conn = put(conn, Routes.moderation_ban_path(conn, :update, ban), ban: @update_attrs)
      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)

      conn = get(conn, Routes.moderation_ban_path(conn, :show, ban))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      conn = put(conn, Routes.moderation_ban_path(conn, :update, ban), ban: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_ban_path(conn, :update, -1), ban: @invalid_attrs)
      end
    end
  end

  describe "delete ban" do
    test "deletes chosen ban", %{conn: conn} do
      ban = ModerationTestLib.ban_fixture()
      conn = delete(conn, Routes.moderation_ban_path(conn, :delete, ban))
      assert redirected_to(conn) == Routes.moderation_ban_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_ban_path(conn, :show, ban))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.moderation_ban_path(conn, :delete, -1))
      end
    end
  end
end
