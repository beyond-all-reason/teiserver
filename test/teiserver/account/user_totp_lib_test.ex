defmodule Teiserver.Account.TOTPLibTest do
  use Teiserver.DataCase, async: false

  alias Teiserver.Account.{TOTPLib, TOTP}
  alias Central.Helpers.GeneralTestLib
  alias NimbleTOTP

  defp users(_context) do
    user_with_totp = GeneralTestLib.make_user(%{name: "has_totp"})
    user_without_totp = GeneralTestLib.make_user(%{name: "has_no_totp"})

    secret = NimbleTOTP.secret()
    {:ok, _totp} = TOTPLib.set_secret(user_with_totp, secret)
    %{user_without_totp: user_without_totp, user_with_totp: user_with_totp, secret: secret}
  end

  defp last_used(_context) do
    %{last_used: ~N[2025-01-01 00:00:00]}
  end

  # ----------------------------------------
  # Database write functions
  # ----------------------------------------

  describe "set_secret/2" do
    setup [:users]

    test "sets secret for user", %{user_without_totp: user} do
      secret = NimbleTOTP.secret()
      assert {:ok, totp} = TOTPLib.set_secret(user, secret)
      assert totp.secret == secret

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.secret == secret
    end
  end

  describe "set_last_used/2" do
    setup [:users, :last_used]

    test "updates last_used for user with secret", %{user_with_totp: user, last_used: last_used} do
      assert {:ok, totp} = TOTPLib.set_last_used(user, last_used)
      assert totp.last_used == last_used

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.last_used == last_used
    end

    test "does not update last_used for user without secret", %{user_without_totp: user} do
      last_used = "123456"
      assert {:inactive, user} = TOTPLib.set_last_used(user, last_used)
      assert :inactive = TOTPLib.get_user_totp_status(user)
    end
  end

  describe "disable_totp/1" do
    setup [:users]

    test "removes TOTP for user with TOTP", %{user_with_totp: user, secret: secret} do
      {:ok, deleted_totp} = TOTPLib.disable_totp(user)
      assert deleted_totp.secret == secret

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp == nil
    end

    test "handles user without secret", %{user_without_totp: user} do
      TOTPLib.disable_totp(user)
      assert {:ok, nil} = TOTPLib.disable_totp(user)
    end
  end

  # ----------------------------------------
  # Get functions
  # ----------------------------------------

  describe "get_user_totp_status/1" do
    setup [:users]

    test "returns :active for user with TOTP", %{user_with_totp: user} do
      assert TOTPLib.get_user_totp_status(user) == :active
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_user_totp_status(user) == :inactive
    end
  end

  describe "get_or_generate_secret/1" do
    setup [:users]

    test "returns existing secret from user with TOTP", %{user_with_totp: user, secret: secret} do
      {:existing, returned} = TOTPLib.get_or_generate_secret(user)
      assert returned == secret
    end

    test "generates new secret if not set", %{user_without_totp: user} do
      {:new, secret} = TOTPLib.get_or_generate_secret(user)
      assert secret != nil
      assert String.length(secret) > 0
    end
  end

  describe "get_user_secret/1" do
    setup [:users]

    test "returns secret for active user", %{user_with_totp: user, secret: secret} do
      assert TOTPLib.get_user_secret(user) == secret
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_user_secret(user) == :inactive
    end
  end

  describe "get_last_used_otp/1" do
    setup [:users, :last_used]

    test "returns last_used for active user", %{user_with_totp: user, last_used: last_used} do
      {:ok, _} = TOTPLib.set_last_used(user, last_used)
      assert TOTPLib.get_last_used_otp(user) == last_used
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_last_used_otp(user) == :inactive
    end
  end

  # ----------------------------------------
  # Verification and otpauth_uri generation
  # ----------------------------------------

  describe "validate_totp/2" do
    setup [:users]

    test "can use same, correct OTP only once, not multiple times", %{
      user_with_totp: user,
      secret: secret
    } do
      otp = NimbleTOTP.verification_code(secret, time: 30)
      assert {:ok, :valid} = TOTPLib.validate_totp(user, otp, 30)
      assert {:error, :used} = TOTPLib.validate_totp(user, otp, 31)
      otp = NimbleTOTP.verification_code(secret, time: 90)
      assert {:ok, :valid} = TOTPLib.validate_totp(user, otp, 90)
    end

    test "allows otp to be used up to 5 seconds after it runs out", %{
      user_with_totp: user,
      secret: secret
    } do
      otp = NimbleTOTP.verification_code(secret, time: 30)
      assert {:ok, :grace} = TOTPLib.validate_totp(user, otp, 64)
      assert {:error, :invalid} = TOTPLib.validate_totp(user, otp, 65)
    end

    test "handles no TOTP", %{user_without_totp: user} do
      assert {:error, :inactive} = TOTPLib.validate_totp(user, "000000")
    end

    test "does not work for wrong/outdated OTP", %{user_with_totp: user, secret: secret} do
      otp = NimbleTOTP.verification_code(secret, time: 30)
      assert {:error, :invalid} = TOTPLib.validate_totp(user, otp, 90)
    end
  end
end
