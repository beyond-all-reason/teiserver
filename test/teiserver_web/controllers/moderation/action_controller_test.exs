defmodule TeiserverWeb.Moderation.ActionControllerTest do
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

  @create_attrs %{
    reason: "some name",
    restrictions: %{"Login" => "Login"},
    expires: "1 day",
    score_modifier: "10000"
  }
  @update_attrs %{reason: "some updated name", restrictions: %{"Warning" => "Warning"}}
  @invalid_attrs %{reason: nil, restrictions: %{}}

  describe "index" do
    test "lists all actions", %{conn: conn} do
      conn = get(conn, ~p"/moderation/action")
      assert html_response(conn, 200) =~ "Listing Actions"

      # Now with an action present
      ModerationTestLib.action_fixture()

      conn = get(conn, ~p"/moderation/action")
      assert html_response(conn, 200) =~ "Listing Actions"
    end

    test "search", %{conn: conn} do
      conn =
        post(
          conn,
          ~p"/moderation/action/search",
          action: %{"order" => "Latest expiry first"}
        )

      assert html_response(conn, 200) =~ "Listing Actions"
    end

    test "list actions for a user", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        get(conn, ~p"/moderation/action" <> "?target_id=#{action.target_id}")

      assert html_response(conn, 200) =~ "Listing Actions"
    end
  end

  describe "new action" do
    test "renders creation form", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        get(
          conn,
          ~p"/moderation/action/new_with_user?teiserver_user=#{user.id}"
        )

      assert html_response(conn, 200) =~ "Adding action against"
    end
  end

  describe "create action" do
    test "redirects to show when data is valid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, ~p"/moderation/action/", action: Map.put(@create_attrs, "target_id", user.id))

      assert redirected_to(conn) == ~p"/moderation/action"

      new_action = Moderation.list_actions(search: [target_id: user.id])
      assert Enum.count(new_action) == 1
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user = GeneralTestLib.make_user()

      conn =
        post(conn, ~p"/moderation/action/", action: Map.put(@invalid_attrs, "target_id", user.id))

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "show action" do
    test "renders show page", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      resp = get(conn, ~p"/moderation/action/#{action.id}")
      assert html_response(resp, 200) =~ "Edit action"
    end

    test "renders show nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/moderation/action/-1")
      end
    end
  end

  describe "edit action" do
    test "renders form for editing nil", %{conn: conn} do
      assert_error_sent 404, fn ->
        get(conn, ~p"/moderation/action/-1/edit")
      end
    end

    test "renders form for editing chosen action", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      conn = get(conn, ~p"/moderation/action/#{action.id}/edit")
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update action" do
    test "redirects when data is valid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        put(conn, ~p"/moderation/action/#{action.id}", action: @update_attrs)

      assert redirected_to(conn) == ~p"/moderation/action/#{action.id}"

      conn = get(conn, ~p"/moderation/action/#{action.id}")
      assert html_response(conn, 200) =~ "some updated"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      action = ModerationTestLib.action_fixture()

      conn =
        put(conn, ~p"/moderation/action/#{action.id}", action: @invalid_attrs)

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end

    test "renders errors when nil object", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, ~p"/moderation/action/-1", action: @invalid_attrs)
      end
    end
  end

  describe "halt action" do
    test "halts chosen action", %{conn: conn} do
      action = ModerationTestLib.action_fixture()
      assert NaiveDateTime.compare(action.expires, NaiveDateTime.utc_now()) == :gt

      conn = put(conn, ~p"/moderation/action/halt/#{action.id}")
      assert redirected_to(conn) == ~p"/moderation/action/#{action.id}"

      action = Moderation.get_action!(action.id)
      assert NaiveDateTime.compare(action.expires, NaiveDateTime.utc_now()) == :lt
    end

    test "renders error for halting nil item", %{conn: conn} do
      assert_error_sent 404, fn ->
        put(conn, ~p"/moderation/action/halt/-1")
      end
    end
  end
end
