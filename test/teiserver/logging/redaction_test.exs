defmodule Teiserver.Logging.RedactionTest do
  @moduledoc """
  Tests that sensitive fields in Ecto schemas are properly redacted when inspected.
  This helps prevent sensitive data from leaking into logs.

  When a field has `redact: true`, Ecto hides it from inspect output (shows as `...`).
  """
  use ExUnit.Case, async: true

  describe "OAuth schema redaction" do
    test "OAuth.Token.value is not shown when inspected" do
      token = %Teiserver.OAuth.Token{value: "secret_token_value"}
      inspected = inspect(token)

      # The sensitive value should NOT appear in the inspected output
      refute inspected =~ "secret_token_value"
      # Redacted fields are hidden (shown as ... at the end)
      assert inspected =~ "..."
    end

    test "OAuth.Code.value is not shown when inspected" do
      code = %Teiserver.OAuth.Code{value: "auth_code_123"}
      inspected = inspect(code)

      refute inspected =~ "auth_code_123"
      assert inspected =~ "..."
    end

    test "OAuth.Code.challenge is not shown when inspected" do
      code = %Teiserver.OAuth.Code{challenge: "pkce_challenge_secret"}
      inspected = inspect(code)

      refute inspected =~ "pkce_challenge_secret"
      assert inspected =~ "..."
    end

    test "OAuth.Credential.hashed_secret is not shown when inspected" do
      credential = %Teiserver.OAuth.Credential{hashed_secret: "hashed_secret_bytes"}
      inspected = inspect(credential)

      refute inspected =~ "hashed_secret_bytes"
      assert inspected =~ "..."
    end
  end

  describe "Account schema redaction" do
    test "Account.UserToken.value is not shown when inspected" do
      token = %Teiserver.Account.UserToken{value: "user_session_token"}
      inspected = inspect(token)

      refute inspected =~ "user_session_token"
      assert inspected =~ "..."
    end

    test "Account.Code.value is not shown when inspected" do
      code = %Teiserver.Account.Code{value: "password_reset_code"}
      inspected = inspect(code)

      refute inspected =~ "password_reset_code"
      assert inspected =~ "..."
    end

    test "Account.TOTP.secret is not shown when inspected" do
      totp = %Teiserver.Account.TOTP{secret: "totp_secret_key"}
      inspected = inspect(totp)

      refute inspected =~ "totp_secret_key"
      assert inspected =~ "..."
    end

    test "Account.User.password is not shown when inspected" do
      user = %Teiserver.Account.User{password: "hashed_password_value"}
      inspected = inspect(user)

      refute inspected =~ "hashed_password_value"
      assert inspected =~ "..."
    end
  end
end
