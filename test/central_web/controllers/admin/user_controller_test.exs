defmodule CentralWeb.Admin.UserControllerTest do
  use CentralWeb.ConnCase

  alias Central.Account

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup(
      ~w(admin admin.user admin.user.show admin.user.create admin.user.update admin.user.report)
    )
  end

  @create_attrs %{
    colour: "some colour",
    email: "some email",
    icon: "far fa-home",
    name: "some name",
    permissions: [],
    username: "some username",
    password: "some password",
    data: "{}"
  }
  @update_attrs %{
    colour: "some updated colour",
    icon: "fas fa-wrench",
    name: "some updated name",
    permissions: [],
    username: "some updated username",
    password: "some updated password",
    data: "{}"
  }
  @invalid_attrs %{colour: nil, icon: nil, name: nil, permissions: nil, username: nil, data: nil}

  def fixture(:user) do
    {:ok, user} = Account.create_user(@create_attrs)
    user
  end

  describe "index" do
    test "lists all users", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index))
      assert html_response(conn, 200) =~ "Users - "
    end

    test "lists all users - redirect", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :index) <> "?s=main user")
      assert redirected_to(conn) == Routes.admin_user_path(conn, :show, 1)
    end

    test "search", %{conn: conn} do
      conn = post(conn, Routes.admin_user_path(conn, :search), search: %{})
      assert html_response(conn, 200) =~ "Users - "
    end

    test "search with redirect", %{conn: conn} do
      conn = post(conn, Routes.admin_user_path(conn, :search), search: %{"name" => "main user"})
      assert redirected_to(conn) == Routes.admin_user_path(conn, :show, 1)
    end
  end

  describe "new user" do
    test "renders form", %{conn: conn} do
      conn = get(conn, Routes.admin_user_path(conn, :new))
      assert html_response(conn, 200) =~ "Save changes"
    end
  end

  describe "create user" do
    test "redirects to show when data is valid", %{conn: conn, child_group: child_group} do
      conn =
        post(conn, Routes.admin_user_path(conn, :create),
          user: Map.put(@create_attrs, :admin_group_id, child_group.id)
        )

      # assert %{id: id} = redirected_params(conn)
      # assert redirected_to(conn) == Routes.admin_user_path(conn, :show, id)
      assert redirected_to(conn) == Routes.admin_user_path(conn, :index)

      new_user = Account.list_users(search: [name: @create_attrs.name])
      assert Enum.count(new_user) == 1

      # conn = get(conn, Routes.admin_user_path(conn, :show, id))
      # assert html_response(conn, 200) =~ "Show User"
    end

    test "renders errors when data is invalid", %{conn: conn} do
      conn = post(conn, Routes.admin_user_path(conn, :create), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  describe "edit user" do
    test "reset password", %{conn: conn, user: user} do
      conn = get(conn, Routes.admin_user_path(conn, :reset_password, user))
      assert conn.private[:phoenix_flash]["success"] == "Password reset to 'pass'."
      assert redirected_to(conn) == Routes.admin_user_path(conn, :edit, user)
    end

    test "renders form for editing nil", %{conn: conn} do
      resp = get(conn, Routes.admin_user_path(conn, :edit, -1))
      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end

    test "renders form for editing chosen user", %{conn: conn, user: user} do
      conn = get(conn, Routes.admin_user_path(conn, :edit, user))
      assert html_response(conn, 200) =~ "Reset password"
    end

    test "renders form for editing secured user", %{conn: conn, parent_group: parent_group} do
      user2 =
        GeneralTestLib.make_user(%{
          "name" => "secured-user",
          "admin_group_id" => "#{parent_group.id}"
        })

      resp = get(conn, Routes.admin_user_path(conn, :edit, user2))
      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end
  end

  describe "permissions" do
    test "edit permissions", %{conn: conn, user: user} do
      resp = get(conn, Routes.admin_user_path(conn, :edit_permissions, user))

      assert html_response(resp, 200) =~ "Save changes"
      refute html_response(resp, 200) =~ "Password confirm"
    end

    test "edit_permissions nil resource", %{conn: conn} do
      resp = get(conn, Routes.admin_user_path(conn, :edit_permissions, -1))

      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end

    test "edit_permissions secured resource", %{conn: conn, parent_group: parent_group} do
      user2 =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2",
          "admin_group_id" => "#{parent_group.id}"
        })

      resp = get(conn, Routes.admin_user_path(conn, :edit_permissions, user2))

      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end

    test "update permissions", %{conn: conn, main_group: main_group} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2",
          "admin_group_id" => "#{main_group.id}"
        })

      resp =
        post(conn, Routes.admin_user_path(conn, :update_permissions, user),
          permissions: %{
            "\"admin.user\"" => [
              "admin.user.show",
              "admin.user.create",
              "admin.user.update",
              "admin.user.delete",
              "admin.user.report"
            ]
          }
        )

      assert resp.private[:phoenix_flash]["success"] == "User permissions updated successfully."
      assert redirected_to(resp) == Routes.admin_user_path(resp, :show, user) <> "#permissions"
    end

    test "update permissions from source", %{conn: conn, main_group: main_group} do
      target_user =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2-target",
          "admin_group_id" => "#{main_group.id}"
        })

      source_user =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2-source",
          "admin_group_id" => "#{main_group.id}",
          "permissions" => [
            "admin.user.show",
            "admin.user.create",
            "admin.user.update",
            "admin.user.delete",
            "admin.user.report"
          ]
        })

      resp =
        post(conn, Routes.admin_user_path(conn, :update_permissions, target_user),
          account_user: source_user.id
        )

      assert resp.private[:phoenix_flash]["success"] == "User permissions updated successfully."

      assert redirected_to(resp) ==
               Routes.admin_user_path(resp, :show, target_user) <> "#permissions"
    end

    test "wipe", %{conn: conn, main_group: main_group} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2",
          "admin_group_id" => "#{main_group.id}",
          "permissions" => ["xyz"]
        })

      assert user.permissions != []
      resp = post(conn, Routes.admin_user_path(conn, :update_permissions, user))

      assert resp.private[:phoenix_flash]["success"] == "User permissions updated successfully."
      assert redirected_to(resp) == Routes.admin_user_path(resp, :show, user) <> "#permissions"

      user = Account.get_user!(user.id)
      assert user.permissions == []
    end

    test "update_permissions nil resource", %{conn: conn} do
      resp = post(conn, Routes.admin_user_path(conn, :update_permissions, -1), permissions: %{})

      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end

    test "update_permissions secured resource", %{conn: conn, parent_group: parent_group} do
      user2 =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2",
          "admin_group_id" => "#{parent_group.id}"
        })

      resp =
        post(conn, Routes.admin_user_path(conn, :update_permissions, user2), permissions: %{})

      assert resp.private[:phoenix_flash]["danger"] == "Unable to find that user"
      assert redirected_to(resp) == Routes.admin_user_path(conn, :index)
    end
  end

  describe "update user" do
    test "redirects when data is valid", %{conn: conn, main_group: main_group} do
      user =
        GeneralTestLib.make_user(%{
          "email" => "user2@user2",
          "admin_group_id" => "#{main_group.id}"
        })

      conn = put(conn, Routes.admin_user_path(conn, :update, user), user: @update_attrs)
      assert redirected_to(conn) == Routes.admin_user_path(conn, :show, user)
      # assert redirected_to(conn) == Routes.admin_user_path(conn, :index)

      conn = get(conn, Routes.admin_user_path(conn, :show, user))
      assert html_response(conn, 200) =~ "some updated colour"
    end

    test "renders errors when data is invalid", %{conn: conn, user: user} do
      conn = put(conn, Routes.admin_user_path(conn, :update, user), user: @invalid_attrs)
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
    end
  end

  # describe "delete user" do
  #   test "deletes chosen user", %{conn: conn, user: user} do
  #     conn = delete(conn, Routes.admin_user_path(conn, :delete, user))
  #     assert redirected_to(conn) == Routes.admin_user_path(conn, :index)
  #     assert_error_sent 404, fn ->
  #       get(conn, Routes.admin_user_path(conn, :show, user))
  #     end
  #   end
  # end
end
