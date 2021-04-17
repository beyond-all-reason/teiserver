defmodule CentralWeb.Account.ForgottenPasswordControllerTest do
  use CentralWeb.ConnCase
  alias Central.Account
  alias Central.Account.UserLib
  alias Central.Helpers.GeneralTestLib
  use Bamboo.Test

  setup do
    GeneralTestLib.conn_setup([], [:no_login])
  end

  describe "mark password as forgotten" do
    test "render form", %{conn: conn} do
      conn = get(conn, Routes.account_session_path(conn, :forgot_password))

      assert html_response(conn, 200) =~
               "Please enter the email address of your account here. A link to reset your password will be sent to the address."
    end
  end

  describe "submit request" do
    test "email2 - not empty", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.account_session_path(conn, :send_password_reset),
          email: dummy.email,
          email2: dummy.email
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["success"] == nil
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == nil
    end

    test "just email", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      conn =
        post(conn, Routes.account_session_path(conn, :send_password_reset),
          email: dummy.email,
          email2: ""
        )

      assert html_response(conn, 200) =~ "Password reset request"
      assert conn.private[:phoenix_flash]["success"] == nil
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == "Form timeout"
    end

    test "Existing request", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, _code} =
        Account.create_code(%{
          value: "existing-request-test-code",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn =
        post(conn, Routes.account_session_path(conn, :send_password_reset),
          email: dummy.email,
          email2: ""
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["success"] == "Existing password reset already sent out"
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == nil
    end

    test "bad key-value pair", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      key = "bad-key-value-pair-key"
      value = "bad-key-value-pair-value"
      ConCache.put(:codes, key, value)

      conn =
        post(conn, Routes.account_session_path(conn, :send_password_reset),
          email: dummy.email,
          email2: "",
          key: key,
          value: "x"
        )

      assert html_response(conn, 200) =~ "Password reset request"
      assert conn.private[:phoenix_flash]["success"] == nil
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == "The form has timed out"
    end

    test "no user", %{conn: conn} do
      key = "no-user-key"
      value = "no-user-value"
      ConCache.put(:codes, key, value)

      params = %{
        "email" => "no-user-email@x",
        "email2" => "",
        "key" => key,
        key => value
      }

      conn = post(conn, Routes.account_session_path(conn, :send_password_reset), params)
      assert html_response(conn, 200) =~ "Password reset request"
      assert conn.private[:phoenix_flash]["success"] == nil
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == "No user by that email"
    end

    test "correctly submitted", %{conn: conn} do
      dummy = GeneralTestLib.make_user()
      key = "correctly-submitted-key"
      value = "correctly-submitted-value"
      ConCache.put(:codes, key, value)

      params = %{
        "email" => dummy.email,
        "email2" => "",
        "key" => key,
        key => value
      }

      conn = post(conn, Routes.account_session_path(conn, :send_password_reset), params)
      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["success"] == "Password reset sent out"
      assert conn.private[:phoenix_flash]["warning"] == nil
      assert conn.private[:phoenix_flash]["info"] == nil

      code =
        Account.list_codes(
          where: [
            user_id: dummy.id,
            purpose: "reset_password"
          ]
        )
        |> hd

      expected_email = UserLib.reset_password_request(dummy, code)
      assert_delivered_email(expected_email)
    end
  end

  describe "reset password form" do
    test "no link", %{conn: conn} do
      conn =
        get(conn, Routes.account_session_path(conn, :password_reset_form, "--non-valid-code--"))

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Unable to find link"
    end

    test "not a reset_password link", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "not-password-reset",
          purpose: "not-password-reset",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn = get(conn, Routes.account_session_path(conn, :password_reset_form, code.value))
      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Link cannot be found"
    end

    test "expired", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "expired-password-reset",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: -24),
          user_id: dummy.id
        })

      conn = get(conn, Routes.account_session_path(conn, :password_reset_form, code.value))
      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Link has expired"
    end

    test "good link", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "expired-password-reset",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn = get(conn, Routes.account_session_path(conn, :password_reset_form, code.value))
      assert html_response(conn, 200) =~ "Password reset form"
      assert html_response(conn, 200) =~ "Please enter your new password."
    end
  end

  describe "reset password post" do
    test "nil code", %{conn: conn} do
      conn =
        post(conn, Routes.account_session_path(conn, :password_reset_post, "--no-code-value--"),
          pass1: "",
          pass2: ""
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Unable to find link"
    end

    test "bad purpose", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "not-password-reset",
          purpose: "not-password-reset",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn =
        post(conn, Routes.account_session_path(conn, :password_reset_post, code.value),
          pass1: "",
          pass2: ""
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Link cannot be found"
    end

    test "expired", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "expired-password-reset",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: -24),
          user_id: dummy.id
        })

      conn =
        post(conn, Routes.account_session_path(conn, :password_reset_post, code.value),
          pass1: "",
          pass2: ""
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["warning"] == "Link has expired"
    end

    test "passwords don't line up", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "not-lining-up",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn =
        post(conn, Routes.account_session_path(conn, :password_reset_post, code.value),
          pass1: "valid",
          pass2: "noooope"
        )

      assert html_response(conn, 200) =~ "Password reset form"
      assert conn.private[:phoenix_flash]["warning"] == "Passwords need to match"
    end

    test "correct", %{conn: conn} do
      dummy = GeneralTestLib.make_user()

      {:ok, code} =
        Account.create_code(%{
          value: "valid-reset",
          purpose: "reset_password",
          expires: Timex.now() |> Timex.shift(hours: 24),
          user_id: dummy.id
        })

      conn =
        post(conn, Routes.account_session_path(conn, :password_reset_post, code.value),
          pass1: "password1",
          pass2: "password1"
        )

      assert redirected_to(conn) == "/"
      assert conn.private[:phoenix_flash]["success"] == "Your password has been reset."
    end
  end
end
