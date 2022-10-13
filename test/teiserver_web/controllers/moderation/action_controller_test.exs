defmodule TeiserverWeb.Moderation.ActionControllerTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.ModerationTestLib

  alias Teiserver.Helpers.GeneralTestLib
  setup do
    GeneralTestLib.conn_setup(~w(horizon.manage))
  end

  @create_attrs %{name: "some name"}
  @update_attrs %{name: "some updated name"}
  @invalid_attrs %{name: nil}

  describe "index" do
    test "lists all actions", %{conn: conn} do
      conn = get(conn, Routes.moderation_action_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Actions"
    end
  end

  describe "new action" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.moderation_action_path(conn, :new))
      assert html_response(conn, 200) =~ "Create"
    end
  end

  describe "create action" do
    test "redirects to show when data is valid", %{conn: conn} do
      conn = post(conn, Routes.moderation_action_path(conn, :create), action: @create_attrs)
      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)

      new_action = Moderation.list_actions(search: [name: @create_attrs.name])
      assert Enum.count(new_action) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.moderation_action_path(conn, :create), action: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show action" do
    test "renders show page", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      resp = get(conn, Routes.moderation_action_path(conn, :show, action))
      assert html_response(resp, 200) =~ "Edit action"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_action_path(conn, :show, -1))
      end
    end
  end

  describe "edit action" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_action_path(conn, :edit, -1))
      end
    end

    test "renders form for editing chosen action", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      conn = get(conn, Routes.moderation_action_path(conn, :edit, action))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update action" do
    test "redirects when data is valid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      conn = put(conn, Routes.moderation_action_path(conn, :update, action), action: @update_attrs)
      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)

      conn = get(conn, Routes.moderation_action_path(conn, :show, action))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      conn = put(conn, Routes.moderation_action_path(conn, :update, action), action: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_action_path(conn, :update, -1), action: @invalid_attrs)
      end
    end
  end

  describe "delete action" do
    test "deletes chosen action", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      conn = delete(conn, Routes.moderation_action_path(conn, :delete, action))
      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)
      assert_error_sent 404, fn ->
        get(conn, Routes.moderation_action_path(conn, :show, action))
      end
    end

    test "renders error for deleting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        delete(conn, Routes.moderation_action_path(conn, :delete, -1))
      end
    end
  end
end
