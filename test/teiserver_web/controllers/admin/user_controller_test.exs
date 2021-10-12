defmodule TeiserverWeb.Admin.UserControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib
  # alias Teiserver.TeiserverTestLib

  setup do
    GeneralTestLib.conn_setup(Teiserver.TeiserverTestLib.admin_permissions())
    |> Teiserver.TeiserverTestLib.conn_setup()
  end

  # @create_attrs %{
  #   colour: "some colour",
  #   email: "some email",
  #   icon: "far fa-home",
  #   name: "some name",
  #   permissions: [],
  #   username: "some username",
  #   password: "some password",
  #   data: "{}"
  # }
  @update_attrs %{
    colour: "some updated colour",
    icon: "fas fa-wrench",
    name: "some updated name",
    username: "some updated username"
  }
  @invalid_attrs %{colour: nil, icon: nil, name: nil, permissions: nil, username: nil, data: nil}

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.ts_admin_user_path(conn, :index))
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "lists all users - redirect", %{conn: conn} do
      main_user = Central.Account.get_user_by_name("main user")
      conn = get(conn, Routes.ts_admin_user_path(conn, :index) <> "?s=main user")
      assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, main_user.id)
    end

    test "search", %{conn: conn} do
      conn = post(conn, Routes.ts_admin_user_path(conn, :search), search: %{})
      assert html_response(conn, 200) =~ "Listing Users"
    end

    test "search with redirect", %{conn: conn} do
      main_user = Central.Account.get_user_by_name("main user")
      conn =
        post(conn, Routes.ts_admin_user_path(conn, :search), search: %{"name" => "main user"})

      assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, main_user.id)
    end
  end

  describe "show user" do
    test "renders form", %{conn: conn, user: user} do
      conn = get(conn, Routes.ts_admin_user_path(conn, :show, user.id))
      assert html_response(conn, 200) =~ "Reports"
    end
  end

  describe "new user" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.ts_admin_user_path(conn, :new))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  # describe "create user" do
  #   test "redirects to show when data is valid", %{conn: conn, child_group: child_group} do
  #     conn =
  #       post(conn, Routes.ts_admin_user_path(conn, :create),
  #         user: Map.put(@create_attrs, :admin_group_id, child_group.id)
  #       )

  #     # assert %{id: id} = redirected_params(conn)
  #     # assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, id)
  #     assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :index)

  #     new_user = Account.list_users(search: [name: @create_attrs.name])
  #     assert Enum.count(new_user) == 1

  #     # conn = get(conn, Routes.ts_admin_user_path(conn, :show, id))
  #     # assert html_response(conn, 200) =~ "Show User"
  #   end

  #   test "renders errors when data is invalid", %{conn: conn} do
  #     conn = post(conn, Routes.ts_admin_user_path(conn, :create), user: @invalid_attrs)
  #     assert html_response(conn, 200) =~ "Oops, something went wrong!"
  #   end
  # end

  describe "edit user" do
    test "renders form for editing nil", %{conn: conn} do
      resp = get(conn, Routes.ts_admin_user_path(conn, :edit, -1))
      assert resp.private[:phoenix_flash]["warning"] == "Unable to access this user"
      assert redirected_to(resp) == Routes.ts_admin_user_path(conn, :index)
    end

    test "renders form for editing chosen user", %{conn: conn, user: user} do
      conn = get(conn, Routes.ts_admin_user_path(conn, :edit, user))
      assert html_response(conn, 200) =~ "Verified"
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "update user" do
    test "redirects when data is valid", %{conn: conn, main_group: main_group} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "tsuser2@tsuser2",
          "admin_group_id" => "#{main_group.id}",
          "data" => %{}
        })

      conn = put(conn, Routes.ts_admin_user_path(conn, :update, user), user: @update_attrs)
      assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, user)
      # assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :index)

      conn = get(conn, Routes.ts_admin_user_path(conn, :show, user))
      assert html_response(conn, 200) =~ "some updated colour"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.ts_admin_user_path(conn, :update, user), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
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
  #     assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, user.id) <> "#reports_tab"

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
  #     assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, user.id) <> "#reports_tab"

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
  #     assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, user.id) <> "#reports_tab"

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
  #     assert redirected_to(conn) == Routes.ts_admin_user_path(conn, :show, user.id) <> "#reports_tab"

  #     cached_user = UserCache.get_user_by_id(user.id)
  #     [banned, until] = cached_user.banned
  #     assert banned == true
  #     assert until == nil
  #     assert Client.get_client_by_id(user.id) == nil
  #   end
  # end
end
