defmodule TeiserverWeb.Admin.UserControllerTest do
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    GeneralTestLib.conn_setup(TeiserverTestLib.server_permissions())
    |> TeiserverTestLib.conn_setup()
  end

  @update_attrs %{
    colour: "#0000AA",
    icon: "fa-solid fa-wrench",
    name: "some updated name",
    username: "some updated username"
  }
  @invalid_attrs %{colour: nil, icon: nil, name: nil, permissions: nil, username: nil, data: nil}

  describe "index" do
    test "lists all users", %{conn: conn} do
      _user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user")
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "lists all users - redirect", %{conn: conn} do
      user = AccountFixtures.user_fixture()

      conn = get(conn, ~p"/teiserver/admin/user" <> "?s=#{user.name}")
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}"
    end

    test "search", %{conn: conn} do
      conn = post(conn, ~p"/teiserver/admin/users/search", search: %{})
      assert html_response(conn, 200) =~ "Listing Users"
    end
  end

  describe "show user" do
    test "renders form", %{conn: conn, user: user} do
      conn = get(conn, ~p"/teiserver/admin/user/#{user.id}")
      assert html_response(conn, 200) =~ "Smurf search"
    end
  end

  describe "edit user" do
    test "renders form for editing nil", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/user/#{-1}/edit")
      assert redirected_to(resp) == ~p"/teiserver/admin/user"
    end

    test "renders form for editing chosen user", %{conn: conn, user: user} do
      conn = get(conn, ~p"/teiserver/admin/user/#{user}/edit")
      assert html_response(conn, 200) =~ "Verified"
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update user" do
    test "redirects when data is valid", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "tsuser2@test.local",
          "data" => %{}
        })

      conn = put(conn, ~p"/teiserver/admin/user/#{user}", user: @update_attrs)
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user}"

      conn = get(conn, ~p"/teiserver/admin/user/#{user}")
      assert html_response(conn, 200) =~ "#0000AA"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, ~p"/teiserver/admin/user/#{user}", user: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "rename user" do
    test "redirects when data is valid", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "tsuser_rename@test.local",
          "data" => %{}
        })

      CacheUser.recache_user(user.id)

      conn =
        put(conn, ~p"/teiserver/admin/users/rename_post/#{user.id}", new_name: "new_test_name")

      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user}"

      conn = get(conn, ~p"/teiserver/admin/user/#{user}")
      assert html_response(conn, 200) =~ "new_test_name"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "tsuser_rename_bad@test.local",
          "data" => %{}
        })

      CacheUser.recache_user(user.id)

      conn =
        put(conn, ~p"/teiserver/admin/users/rename_post/#{user.id}",
          new_name: "this_name_is_too_long_and_has_invalid_characters!"
        )

      assert html_response(conn, 200) =~ "New user name:"
    end
  end
end
