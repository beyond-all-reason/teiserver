defmodule TeiserverWeb.Admin.UserControllerTest do
  alias Phoenix.Flash
  alias Teiserver.Account
  alias Teiserver.AccountFixtures
  alias Teiserver.CacheUser
  alias Teiserver.Helpers.GeneralTestLib
  alias Teiserver.TeiserverTestLib

  use TeiserverWeb.ConnCase

  setup do
    TeiserverTestLib.server_permissions()
    |> GeneralTestLib.conn_setup()
    |> TeiserverTestLib.conn_setup()
  end

  @update_attrs %{
    colour: "#0000AA",
    icon: "fa-solid fa-wrench",
    name: "some_updated_name",
    username: "some_updated_username"
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
          "name" => "user",
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

  describe "gdpr forget" do
    test "success", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "name" => "gdpr_forget",
          "email" => "test_gdpr@test.local",
          "data" => %{}
        })

      conn = put(conn, ~p"/admin/users/gdpr_forget/#{user.id}")

      assert Flash.get(conn.assigns.flash, :success) == "User GDPR forgotten"
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}"

      # Now ensure the user has been forgotten
      user = Account.get_user(user.id)
      assert user.name != "gdpr_forget"
      assert user.email != "test_gdpr@test.local"
    end

    test "no access" do
      # Setup something specifically to not have access, currently only
      # moderators have access this so we are testing with contributor
      {:ok, setup_opts} =
        TeiserverTestLib.staff_permissions()
        |> GeneralTestLib.conn_setup([], "test1")
        |> TeiserverTestLib.conn_setup()

      conn = Keyword.get(setup_opts, :conn)

      user =
        GeneralTestLib.make_user(%{
          "name" => "test2",
          "email" => "test_gdpr_no_auth@test.local",
          "data" => %{}
        })

      conn = put(conn, ~p"/admin/users/gdpr_forget/#{user.id}")

      assert Flash.get(conn.assigns.flash, :error) == "Unauthorized"
      assert redirected_to(conn) == ~p"/"

      # Now ensure it didn't run
      user = Account.get_user(user.id)
      assert user.email == "test_gdpr_no_auth@test.local"
    end
  end
end
