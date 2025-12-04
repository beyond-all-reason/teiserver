defmodule Teiserver.Account.TOTPLibTest do
  use Teiserver.DataCase, async: false

  alias Teiserver.Account.{TOTPLib, TOTP}
  alias Central.Helpers.GeneralTestLib
  alias NimbleTOTP

  defp users(_context) do
    user_with_totp = GeneralTestLib.make_user(%{name: "has_totp"})
    user_without_totp = GeneralTestLib.make_user(%{name: "has_no_totp"})

    secret = NimbleTOTP.secret()
    {:ok, _totp} = TOTPLib.set_secret(user_with_totp.id, secret)
    %{user_without_totp: user_without_totp, user_with_totp: user_with_totp, secret: secret}
  end

  # ----------------------------------------
  # Database write functions
  # ----------------------------------------

  describe "set_secret/2" do
    setup [:users]

    test "sets secret for user", %{user_without_totp: user} do
      secret = NimbleTOTP.secret()
      assert {:ok, totp} = TOTPLib.set_secret(user.id, secret)
      assert totp.secret == secret

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.secret == secret
    end
  end

  describe "set_last_used/2" do
    setup [:users]

    test "updates last_used for user with secret", %{user_with_totp: user} do
      now = ~U[1970-01-01 00:00:30Z]
      assert :ok = TOTPLib.set_last_used(user.id, now)

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.last_used == now
    end

    test "does not update last_used for user without secret", %{user_without_totp: user} do
      now = ~U[1970-01-01 00:00:30Z]
      assert :inactive = TOTPLib.set_last_used(user.id, now)
      assert :inactive = TOTPLib.get_user_totp_status(user.id)
    end
  end

  describe "disable_totp/1" do
    setup [:users]

    test "removes TOTP for user with TOTP", %{user_with_totp: user} do
      TOTPLib.disable_totp(user.id)

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp == nil
    end

    test "handles user without secret", %{user_without_totp: user} do
      assert :ok = TOTPLib.disable_totp(user.id)
    end
  end

  # ----------------------------------------
  # Get functions
  # ----------------------------------------

  describe "get_account_locked/1" do
    setup [:users]

    test "returns :active for user without TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_account_locked(user.id) == false
    end

    test "returns :active until 4 wrong otp entry, then :inactive", %{
      user_with_totp: user,
      secret: secret
    } do
      otp = NimbleTOTP.verification_code(secret, time: 0)

      for _i <- 1..5 do
        assert TOTPLib.get_account_locked(user.id) == false
        TOTPLib.validate_totp(user, otp, 100)
      end

      assert TOTPLib.get_account_locked(user.id) == true
    end
  end

  describe "get_user_totp_status/1" do
    setup [:users]

    test "returns :active for user with TOTP", %{user_with_totp: user} do
      assert TOTPLib.get_user_totp_status(user.id) == :active
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_user_totp_status(user.id) == :inactive
    end
  end

  describe "get_or_generate_secret/1" do
    setup [:users]

    test "returns existing secret from user with TOTP", %{user_with_totp: user, secret: secret} do
      {:existing, returned} = TOTPLib.get_or_generate_secret(user.id)
      assert returned == secret
    end

    test "generates new secret if not set", %{user_without_totp: user} do
      {:new, secret} = TOTPLib.get_or_generate_secret(user.id)
      assert secret != nil
      assert String.length(secret) > 0
    end
  end

  describe "get_user_secret/1" do
    setup [:users]

    test "returns secret for active user", %{user_with_totp: user, secret: secret} do
      assert TOTPLib.get_user_secret(user.id) == secret
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_user_secret(user.id) == :inactive
    end
  end

  describe "get_last_used/1" do
    setup [:users]

    test "returns last_used for active user", %{user_with_totp: user} do
      now = ~U[1970-01-01 00:00:30Z]
      :ok = TOTPLib.set_last_used(user.id, now)
      assert TOTPLib.get_last_used(user.id) == now
    end

    test "returns :inactive for user with no TOTP", %{user_without_totp: user} do
      assert TOTPLib.get_last_used(user.id) == :inactive
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
      now = ~U[1970-01-01 00:00:30Z]
      otp = NimbleTOTP.verification_code(secret, time: now)
      assert :ok = TOTPLib.validate_totp(user, otp, now)
      assert {:error, :used} = TOTPLib.validate_totp(user, otp, now)

      # check that next OTP (30 seconds later) will work again
      otp = NimbleTOTP.verification_code(secret, time: DateTime.add(now, 30, :second))
      assert :ok = TOTPLib.validate_totp(user, otp, DateTime.add(now, 30, :second))
    end

    test "handles no TOTP", %{user_without_totp: user} do
      assert {:error, :inactive} = TOTPLib.validate_totp(user, "000000")
    end

    test "does not work for outdated OTP", %{user_with_totp: user, secret: secret} do
      now = ~U[1970-01-01 00:00:30Z]
      otp = NimbleTOTP.verification_code(secret, time: now)
      assert {:error, :invalid} = TOTPLib.validate_totp(user, otp, DateTime.add(now, 30, :second))
    end
  end
end
