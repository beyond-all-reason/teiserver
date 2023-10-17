defmodule TeiserverWeb.Admin.UserControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib
  # alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.server_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  # @create_attrs %{
  #   colour: "some colour",
  #   email: "some email",
  #   icon: "fa-regular fa-home",
  #   name: "some name",
  #   permissions: [],
  #   username: "some username",
  #   password: "some password",
  #   data: "{}"
  # }
  @update_attrs %{
    colour: "some updated colour",
    icon: "fa-solid fa-wrench",
    name: "some updated name",
    username: "some updated username"
  }
  @invalid_attrs %{colour: nil, icon: nil, name: nil, permissions: nil, username: nil, data: nil}

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get(conn, ~p"/teiserver/admin/user")
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "lists all users - redirect", %{conn: conn} do
      main_user = Central.Account.get_user_by_name("dud user")
      conn = get(conn, ~p"/teiserver/admin/user" <> "?s=dud user")
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{main_user.id}"
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

  describe "new user" do
    test "renders form", %{conn: conn} do
      conn = get(conn, ~p"/teiserver/admin/user/new")
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  # describe "create user" do
  #   test "redirects to show when data is valid", %{conn: conn, child_group: child_group} do
  #     conn =
  #       post(conn, ~p"/teiserver/admin/user",
  #         user: Map.put(@create_attrs, :admin_group_id, child_group.id)
  #       )

  #     # assert %{id: id} = redirected_params(conn)
  #     # assert redirected_to(conn) == ~p"/teiserver/admin/user/#{id}"
  #     assert redirected_to(conn) == ~p"/teiserver/admin/user"

  #     new_user = Account.list_users(search: [name: @create_attrs.name])
  #     assert Enum.count(new_user) == 1

  #     # conn = get(conn, ~p"/teiserver/admin/user/#{id}")
  #     # assert html_response(conn, 200) =~ "Show User"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, ~p"/teiserver/admin/user", user: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Oops, something went wrong!"
  #   end
  # end

  describe "edit user" do
    test "renders form for editing nil", %{conn: conn} do
      resp = get(conn, ~p"/teiserver/admin/user/#{-1}/edit")
      # assert resp.private[:phoenix_flash]["danger"] == "Unable to access this user"
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
          "email" => "tsuser2@tsuser2",
          "data" => %{}
        })

      conn = put(conn, ~p"/teiserver/admin/user/#{user}", user: @update_attrs)
      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user}"
      # assert redirected_to(conn) == ~p"/teiserver/admin/user"

      conn = get(conn, ~p"/teiserver/admin/user/#{user}")
      assert html_response(conn, 200) =~ "some updated colour"
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
          "email" => "tsuser_rename@tsuser_rename",
          "data" => %{}
        })

      Teiserver.User.recache_user(user.id)

      conn =
        put(conn, Routes.ts_admin_user_path(conn, :rename_post, user), new_name: "new_test_name")

      assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user}"

      conn = get(conn, ~p"/teiserver/admin/user/#{user}")
      assert html_response(conn, 200) =~ "new_test_name"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "tsuser_rename_bad@tsuser_rename_bad",
          "data" => %{}
        })

      Teiserver.User.recache_user(user.id)

      conn =
        put(conn, Routes.ts_admin_user_path(conn, :rename_post, user),
          new_name: "this_name_is_too_long_and_has_invalid_characters!"
        )

      assert html_response(conn, 200) =~ "New user name:"

      # assert conn.private[:phoenix_flash]["danger"] == "Error with rename: Max length 20 characters"
    end
  end

  # Report action takes place through the hookserver which isn't firing in this mode
  # describe "moderation" do
  #   test "apply temporary mute", %{conn: conn} do
  #     %{user: user} = TeiserverTestLib.tachyon_auth_setup()

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     assert cached_user.muted == [false, nil]

  #     conn = put(conn, Routes.ts_admin_user_path(conn, :perform_action, user.id, "report_action"), %{
  #       report_response_action: "Mute",
  #       reason: "test reason",
  #       until: "5 minutes"
  #     })
  #     assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}" <> "#reports_tab"

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     [muted, until] = cached_user.muted
  #     assert muted == true
  #     assert until != nil
  #   end

  #   test "apply permanent mute", %{conn: conn} do
  #     %{user: user} = TeiserverTestLib.tachyon_auth_setup()

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     assert cached_user.muted == [false, nil]

  #     conn = put(conn, Routes.ts_admin_user_path(conn, :perform_action, user.id, "report_action"), %{
  #       report_response_action: "Mute",
  #       reason: "test reason",
  #       until: "never"
  #     })
  #     assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}" <> "#reports_tab"

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     [muted, until] = cached_user.muted
  #     assert muted == true
  #     assert until == nil
  #   end

  #   test "apply temporary ban", %{conn: conn} do
  #     %{user: user} = TeiserverTestLib.tachyon_auth_setup()

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     assert cached_user.banned == [false, nil]
  #     assert Client.get_client_by_id(user.id)

  #     conn = put(conn, Routes.ts_admin_user_path(conn, :perform_action, user.id, "report_action"), %{
  #       report_response_action: "Ban",
  #       reason: "test reason",
  #       until: "5 minutes"
  #     })
  #     assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}" <> "#reports_tab"

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     [banned, until] = cached_user.banned
  #     assert banned == true
  #     assert until != nil
  #     assert Client.get_client_by_id(user.id) == nil
  #   end

  #   test "apply permanent ban", %{conn: conn} do
  #     %{user: user} = TeiserverTestLib.tachyon_auth_setup()

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     assert cached_user.banned == [false, nil]
  #     assert Client.get_client_by_id(user.id)

  #     conn = put(conn, Routes.ts_admin_user_path(conn, :perform_action, user.id, "report_action"), %{
  #       report_response_action: "Ban",
  #       reason: "test reason",
  #       until: "never"
  #     })
  #     assert redirected_to(conn) == ~p"/teiserver/admin/user/#{user.id}" <> "#reports_tab"

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     [banned, until] = cached_user.banned
  #     assert banned == true
  #     assert until == nil
  #     assert Client.get_client_by_id(user.id) == nil
  #   end
  # end
end
