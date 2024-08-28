defmodule TeiserverWeb.Moderation.ActionControllerTest do
  @moduledoc false
  use TeiserverWeb.ConnCase

  alias Teiserver.Moderation
  alias Teiserver.Moderation.ModerationTestLib

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(["Reviewer", "Moderator"])
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  @create_attrs %{
    reason: "some name",
    restrictions: %{"Login" => "Login"},
    expires: "1 day",
    score_modifier: "10000"
  }
  @update_attrs %{reason: "some updated name", restrictions: %{"Warning" => "Warning"}}
  @invalid_attrs %{reason: nil, restrictions: %{}}

  describe "index" do
    @tag :needs_attention
    test "lists all actions", %{conn: conn} do
      conn = get(conn, Routes.moderation_action_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Actions"

      # Now with an action present
      ModerationTestLib.action_fixture()

      conn = get(conn, Routes.moderation_action_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Actions"
    end

    @tag :needs_attention
    test "search", %{conn: conn} do
      conn =
        post(
          conn,
          Routes.moderation_action_path(conn, :search,
            search: %{"order" => "Latest expiry first"}
          )
        )

      assert html_response(conn, 200) =~ "Listing Actions"
    end

    @tag :needs_attention
    test "list actions for a user", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        get(conn, Routes.moderation_action_path(conn, :index) <> "?target_id=#{action.target_id}")

      assert html_response(conn, 200) =~ "Listing Actions"
    end
  end

  describe "new action" do
    test "renders select form", %{conn: conn} do
      conn = get(conn, Routes.moderation_action_path(conn, :new))
      assert html_response(conn, 200) =~ "Select user:"
    end

    test "renders creation form", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        get(
          conn,
          Routes.moderation_action_path(conn, :new_with_user) <> "?teiserver_user=%23#{user.id}"
        )

      assert html_response(conn, 200) =~ "Adding action against"
    end
  end

  describe "create action" do
    test "redirects to show when data is valid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.moderation_action_path(conn, :create),
          action: Map.put(@create_attrs, "target_id", user.id)
        )

      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)

      new_action = Moderation.list_actions(search: [target_id: user.id])
      assert Enum.count(new_action) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.moderation_action_path(conn, :create),
          action: Map.put(@invalid_attrs, "target_id", user.id)
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show action" do
    @tag :needs_attention
    test "renders show page", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      resp = get(conn, Routes.moderation_action_path(conn, :show, action))
      assert html_response(resp, 200) =~ "Edit action"
    end

    @tag :needs_attention
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
    @tag :needs_attention
    test "redirects when data is valid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        put(conn, Routes.moderation_action_path(conn, :update, action), action: @update_attrs)

      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)

      conn = get(conn, Routes.moderation_action_path(conn, :show, action))
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        put(conn, Routes.moderation_action_path(conn, :update, action), action: @invalid_attrs)

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_action_path(conn, :update, -1), action: @invalid_attrs)
      end
    end
  end

  describe "halt action" do
    @tag :needs_attention
    test "halts chosen action", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      assert Timex.compare(action.expires, Timex.now()) == 1

      conn = put(conn, Routes.moderation_action_path(conn, :halt, action.id))
      assert redirected_to(conn) == Routes.moderation_action_path(conn, :index)

      action = Moderation.get_action!(action.id)
      assert Timex.compare(action.expires, Timex.now()) == -1
    end

    test "renders error for halting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, Routes.moderation_action_path(conn, :halt, -1))
      end
    end
  end
end
