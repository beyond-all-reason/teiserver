defmodule CentralWeb.Account.SessionControllerTest do
  use CentralWeb.ConnCase

  alias Central.{Account, Config}
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

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
    end

    test "bad name", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{"user" => @invalid_name_attrs})

      assert conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert html_response(conn, 200) =~ "Sign In"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
    end

    test "bad password", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))

      conn =
        post(conn, Routes.account_session_path(conn, :login), %{"user" => @invalid_pass_attrs})

      assert conn.private[:phoenix_flash]["danger"] == "Invalid credentials"
      assert html_response(conn, 200) =~ "Sign In"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
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

      conn = get(conn, "/")
      assert conn.assigns[:current_user] != nil
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

      conn = get(conn, "/")
      assert conn.assigns[:current_user] != nil
    end
  end

  describe "logout" do
    test "perform", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :logout))
      assert redirected_to(conn) == "/login"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
    end
  end

  describe "one time link" do
    test "no code", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :one_time_login, "no_code"))
      assert redirected_to(conn) == "/"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
    end

    test "bad ip", %{conn: conn, user: user} do
      {:ok, _code} = Account.create_code(%{
        value: "login-code$ip",
        purpose: "one-time-login",
        expires: Timex.now() |> Timex.shift(days: 1),
        user_id: user.id
      })

      conn = get(conn, Routes.account_session_path(conn, :one_time_login, "login-code"))
      assert redirected_to(conn) == "/"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil
    end

    test "good ip", %{conn: conn, user: user} do
      {:ok, _code} = Account.create_code(%{
        value: "login-code-good$127.0.0.1",
        purpose: "one-time-login",
        expires: Timex.now() |> Timex.shift(days: 1),
        user_id: user.id
      })

      # Site config disabled
      Config.update_site_config("user.Enable one time links", false)
      conn = get(conn, Routes.account_session_path(conn, :one_time_login, "login-code-good"))
      assert redirected_to(conn) == "/"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] == nil

      # Now with site config enabled
      Config.update_site_config("user.Enable one time links", "true")
      conn = get(conn, Routes.account_session_path(conn, :one_time_login, "login-code-good"))
      assert redirected_to(conn) == "/"

      conn = get(conn, "/")
      assert conn.assigns[:current_user] != nil
    end
  end
end
