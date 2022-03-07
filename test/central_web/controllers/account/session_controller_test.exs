defmodule CentralWeb.Account.SessionControllerTest do
  use CentralWeb.ConnCase

  alias Central.Helpers.GeneralTestLib

  setup do
    GeneralTestLib.conn_setup([], [:no_login])
  end

  @invalid_name_attrs %{email: "wrong_email@email.com", password: "password"}
  @invalid_pass_attrs %{email: "current_user@current_user.com", password: ""}

  describe "login" do
    test "login form", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))
      conn = get(conn, Routes.account_session_path(conn, :new))
      refute conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert html_response(conn, 200) =~ "Sign In"
    end

    test "bad name", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{"user" => @invalid_name_attrs})

      assert conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert html_response(conn, 200) =~ "Sign In"
    end

    test "bad password", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{"user" => @invalid_pass_attrs})

      assert conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert html_response(conn, 200) =~ "Sign In"
    end

    test "correctly", %{conn: conn, r: r} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{
          "user" => %{
            "email" => "current_user#{r}@current_user#{r}.com",
            "password" => "password"
          }
        })

      refute conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert redirected_to(conn) == "/"
    end

    test "correctly with space after email", %{conn: conn, r: r} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{
          "user" => %{
            "email" => "current_user#{r}@current_user#{r}.com ",
            "password" => "password"
          }
        })

      refute conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert redirected_to(conn) == "/"
    end
  end

  describe "logout" do
    test "perform", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))
      assert redirected_to(conn) == "/login"
    end
  end
end
