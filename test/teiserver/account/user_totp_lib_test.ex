defmodule Teiserver.Account.TOTPLibTest do
  use Teiserver.DataCase, async: false

  alias Teiserver.Account
  alias Teiserver.Account.{TOTPLib, User, TOTP}
  alias NimbleTOTP

  # ----------------------------------------
  # Fixtures
  # ----------------------------------------

  defp valid_user_fixture(attrs \\ %{}) do
    {:ok, user} =
      attrs
      |> Enum.into(%{
        email: "test#{System.unique_integer()}@example.com",
        password: "password123",
        name: "TestUser#{System.unique_integer()}"
      })
      |> Account.create_user()

    user
  end

  setup do
    # Valid user and secret
    valid_user = valid_user_fixture()
    valid_secret = NimbleTOTP.secret()
    {:ok, totp} = TOTPLib.set_secret(valid_user, valid_secret)

    # Invalid user (struct with no fields) and invalid secret
    invalid_user = %User{}
    invalid_secret = "secret"

    # OTP from 30 seconds ago
    old_otp = NimbleTOTP.verification_code(valid_secret, time: System.os_time(:second) - 30)

    {:ok,
     valid_user: valid_user,
     invalid_user: invalid_user,
     valid_secret: valid_secret,
     invalid_secret: invalid_secret,
     totp: totp,
     old_otp: old_otp}
  end

  # ----------------------------------------
  # Database write functions
  # ----------------------------------------

  describe "set_secret/2" do
    test "sets secret for valid user", %{valid_user: user} do
      secret = NimbleTOTP.secret()
      assert {:ok, totp} = TOTPLib.set_secret(user, secret)
      assert totp.secret == secret

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.secret == secret
    end

    test "returns error changeset for invalid user", %{
      invalid_user: invalid_user,
      invalid_secret: invalid_secret
    } do
      assert {:error, %Ecto.Changeset{}} = TOTPLib.set_secret(invalid_user, invalid_secret)
    end
  end

  describe "set_last_used/2" do
    test "updates last_used for valid user", %{valid_user: user} do
      last_used = "123456"
      assert {:ok, totp} = TOTPLib.set_last_used(user, last_used)
      assert totp.last_used == last_used

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp.last_used == last_used
    end

    test "returns error changeset for invalid user", %{invalid_user: invalid_user} do
      last_used = "123456"
      assert {:error, %Ecto.Changeset{}} = TOTPLib.set_last_used(invalid_user, last_used)
    end
  end

  describe "disable_totp/1" do
    test "removes TOTP for active user", %{valid_user: user, valid_secret: secret} do
      {:ok, deleted_totp} = TOTPLib.disable_totp(user)
      assert deleted_totp.secret == secret

      db_totp = Repo.get_by(TOTP, user_id: user.id)
      assert db_totp == nil
    end

    test "returns {:ok, nil} for user with no TOTP", %{valid_user: user} do
      TOTPLib.disable_totp(user)
      assert {:ok, nil} = TOTPLib.disable_totp(user)
    end
  end

  # ----------------------------------------
  # Get functions
  # ----------------------------------------

  describe "get_user_totp_status/1" do
    test "returns :active for user with TOTP", %{valid_user: user} do
      assert TOTPLib.get_user_totp_status(user) == :active
    end

    test "returns :inactive for user with no TOTP", %{invalid_user: invalid_user} do
      assert TOTPLib.get_user_totp_status(invalid_user) == :inactive
    end
  end

  describe "get_or_generate_secret/1" do
    test "returns existing secret if present", %{valid_user: user, valid_secret: secret} do
      {:existing, returned} = TOTPLib.get_or_generate_secret(user)
      assert returned == secret
    end

    test "generates new secret if missing" do
      user = valid_user_fixture()
      {:new, secret} = TOTPLib.get_or_generate_secret(user)
      assert secret != nil
      assert String.length(secret) > 0
    end
  end

  describe "get_user_secret/1" do
    test "returns secret for active user", %{valid_user: user, valid_secret: secret} do
      assert TOTPLib.get_user_secret(user) == secret
    end

    test "returns :inactive for user with no TOTP", %{invalid_user: invalid_user} do
      assert TOTPLib.get_user_secret(invalid_user) == :inactive
    end
  end

  describe "get_last_used_otp/1" do
    test "returns last_used for active user", %{valid_user: user} do
      {:ok, _} = TOTPLib.set_last_used(user, "654321")
      assert TOTPLib.get_last_used_otp(user) == "654321"
    end

    test "returns :inactive for user with no TOTP", %{invalid_user: invalid_user} do
      assert TOTPLib.get_last_used_otp(invalid_user) == :inactive
    end
  end

  # ----------------------------------------
  # Validation functions
  # ----------------------------------------

  describe "validate_last_used/2" do
    test "returns true if OTP matches last_used" do
      assert TOTPLib.validate_last_used("123456", "123456")
    end

    test "returns false if OTP differs from last_used" do
      refute TOTPLib.validate_last_used("123456", "654321")
    end
  end

  describe "validate_totp/2" do
    test "returns {:error, :inactive} for user with no TOTP", %{invalid_user: invalid_user} do
      assert {:error, :inactive} = TOTPLib.validate_totp(invalid_user, "000000")
    end

    test "returns {:ok, :valid} and {:error, :used} for correct OTP used twice", %{
      valid_user: user,
      valid_secret: secret
    } do
      otp = NimbleTOTP.verification_code(secret)
      assert {:ok, :valid} = TOTPLib.validate_totp(user, otp)
      assert {:error, :used} = TOTPLib.validate_totp(user, otp)
    end

    test "returns {:error, :invalid} for OTP from 30 seconds ago", %{
      valid_user: user,
      old_otp: old_otp
    } do
      # Assuming your system allows OTPs within a 30-second window
      assert {:error, :invalid} = TOTPLib.validate_totp(user, old_otp)
    end

    test "returns {:error, :invalid} for wrong OTP", %{
      valid_user: user,
      invalid_secret: invalid_secret
    } do
      assert {:error, :invalid} = TOTPLib.validate_totp(user, invalid_secret)
    end
  end
end
