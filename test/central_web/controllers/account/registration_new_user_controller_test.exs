defmodule CentralWeb.Account.RegistrationNewUserControllerTest do
  use CentralWeb.ConnCase
  alias Central.Account
  alias Central.Account.User

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([], [:no_login])
  end

  @valid_attrs %{
    name: "new user",
    email: "new_user@new_user.com",
    password: "new_password",
    password_confirmation: "new_password"
  }

  describe "create user" do
    test "render form", %{conn: conn} do
      conn = get(conn, Routes.account_registration_path(conn, :new))
      assert html_response(conn, 200) =~ "Register account"
    end

    test "valid attrs", %{conn: conn} do
      conn = post(conn, Routes.account_registration_path(conn, :create), user: @valid_attrs)
      assert conn.private[:phoenix_flash]["info"] == "User created successfully."
      assert redirected_to(conn) == "/"
      new_user = Account.get_user!(search: [name: "new user"])
      assert new_user.email == "new_user@new_user.com"
      assert User.verify_password("new_password", new_user.password)
    end

    test "inlvalid attrs - no details", %{conn: conn} do
      conn = post(conn, Routes.account_registration_path(conn, :create), user: %{})
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "inlvalid attrs - short password", %{conn: conn} do
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.merge(@valid_attrs, %{password: "1234", password_confirmation: "1234"})
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end

    test "inlvalid attrs - mismatched password", %{conn: conn} do
      conn =
        post(conn, Routes.account_registration_path(conn, :create),
          user: Map.put(@valid_attrs, :password_confirmation, "long long password")
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user(search: [name: "new user"])
      assert new_user == nil
    end
  end
end
