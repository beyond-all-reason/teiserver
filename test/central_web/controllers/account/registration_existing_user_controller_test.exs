defmodule CentralWeb.Account.RegistrationExistingUserControllerTest do
  use CentralWeb.ConnCase
  alias Central.Account
  alias Central.Account.User

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([])
  end

  # We use this because the General test lib that seeds this test
  # won't encrypt it correctly as most of the time we
  # don't need to test that, here it's vital we do
  defp reset_current_user_password(user) do
    {:ok, u} = Account.update_user(user, %{"password" => "password"})
    u
  end

  @valid_update_details %{
    name: "Current updated user",
    email: "current_updated_user@current_user.com"
  }
  @invalid_update_details %{name: nil, email: nil}

  describe "details" do
    test "render form", %{conn: conn} do
      conn = get(conn, Routes.account_registration_path(conn, :edit_details))
      assert html_response(conn, 200) =~ "Password confirmation"
      assert html_response(conn, 200) =~ "Update details"
    end

    test "valid attrs - with password", %{conn: conn, user: user} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: Map.put(@valid_update_details, :password_confirmation, "password")
        )

      assert redirected_to(conn) == Routes.account_general_path(conn, :index)
      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current updated user"
      assert new_user.email == "current_updated_user@current_user.com"
    end

    test "valid attrs - no password", %{conn: conn, user: user, r: r} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: @valid_update_details
        )

      assert html_response(conn, 200) =~
               "Please enter your password to change your account details."

      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current user"
      assert new_user.email == "current_user#{r}@current_user#{r}.com"
    end

    test "valid attrs - wrong password", %{conn: conn, user: user, r: r} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: Map.put(@valid_update_details, :password_confirmation, "wrong_password")
        )

      assert html_response(conn, 200) =~ "Incorrect password"
      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current user"
      assert new_user.email == "current_user#{r}@current_user#{r}.com"
    end

    test "invalid attrs - with password", %{conn: conn, user: user, r: r} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: Map.put(@invalid_update_details, :password_confirmation, "password")
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current user"
      assert new_user.email == "current_user#{r}@current_user#{r}.com"
    end

    test "invalid attrs - no password", %{conn: conn, user: user, r: r} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: @invalid_update_details
        )

      assert html_response(conn, 200) =~
               "Please enter your password to change your account details."

      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current user"
      assert new_user.email == "current_user#{r}@current_user#{r}.com"
    end

    test "invalid attrs - wrong password", %{conn: conn, user: user, r: r} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_details),
          user: Map.put(@invalid_update_details, :password_confirmation, "wrong_password")
        )

      assert html_response(conn, 200) =~ "Incorrect password"
      new_user = Account.get_user!(user.id)
      assert new_user.name == "Current user"
      assert new_user.email == "current_user#{r}@current_user#{r}.com"
    end
  end

  describe "password" do
    test "render form", %{conn: conn} do
      conn = get(conn, Routes.account_registration_path(conn, :edit_password))
      assert html_response(conn, 200) =~ "Password confirmation"
      assert html_response(conn, 200) =~ "Update password"
    end

    test "valid attrs", %{conn: conn, user: user} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_password),
          user: %{
            password: "updated_password",
            password_confirmation: "updated_password",
            existing: "password"
          }
        )

      assert redirected_to(conn) == Routes.account_general_path(conn, :index)
      new_user = Account.get_user!(user.id)
      assert User.verify_password("updated_password", new_user.password)
    end

    test "invalid attrs - no existing password", %{conn: conn, user: user} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_password),
          user: %{password: "updated_password", password_confirmation: "updated_password"}
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user!(user.id)
      assert User.verify_password("password", new_user.password)
    end

    test "invalid attrs - incorrect existing password", %{conn: conn, user: user} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_password),
          user: %{
            password: "updated_password",
            password_confirmation: "updated_password",
            existing: "incorrect"
          }
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user!(user.id)
      assert User.verify_password("password", new_user.password)
    end

    test "invalid attrs - non-matching confirm", %{conn: conn, user: user} do
      user = reset_current_user_password(user)

      conn =
        put(conn, Routes.account_registration_path(conn, :update_password),
          user: %{
            password: "updated_password",
            password_confirmation: "incorrect_password",
            existing: "password"
          }
        )

      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user!(user.id)
      assert User.verify_password("password", new_user.password)
    end

    test "invalid attrs - no details", %{conn: conn, user: user} do
      user = reset_current_user_password(user)
      conn = put(conn, Routes.account_registration_path(conn, :update_password), user: %{})
      assert html_response(conn, 200) =~ "Oops, something went wrong!"
      new_user = Account.get_user!(user.id)
      assert User.verify_password("password", new_user.password)
    end
  end
end
