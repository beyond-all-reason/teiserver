defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}

  @spec validate_totp(binary(), String.t()) :: any
  defp validate_totp(secret, otp) do
    now = System.os_time(:second)

    cond do
      NimbleTOTP.valid?(secret, otp, time: now) ->
        {:ok, "valid"}

      NimbleTOTP.valid?(secret, otp, time: System.os_time(:second) - 5) ->
        {:ok, "grace"}

      true ->
        {:error, "invalid"}
    end
  end

  @spec get_or_generate_user_secret(User.t()) :: binary()
  def get_or_generate_user_secret(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      nil ->
        {:ok, totp} = generate_secret(user)
        totp.secret

      totp ->
        totp.secret
    end
  end

  @spec generate_secret(User.t()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  defp generate_secret(%User{id: user_id} = user) do
    secret = NimbleTOTP.secret()

    case get_user_totp(user) do
      nil ->
        %TOTP{}
        |> TOTP.changeset(%{user_id: user_id, secret: secret})
        |> Repo.insert()

      totp ->
        totp
        |> TOTP.changeset(%{secret: secret})
        |> Repo.update()
    end
  end

  def change_totp(%User{} = user, attrs \\ %{}) do
    totp = get_user_totp(user)
    TOTP.changeset(totp, attrs)
  end

  @spec get_totp_status(User.t()) :: boolean
  def get_totp_status(%User{id: _user_id} = user) do
    user_totp = get_user_totp(user)
    user_totp.active
  end

  @spec get_user_totp(User.t()) :: TOTP.t() | nil
  defp get_user_totp(%User{id: user_id}) do
    Repo.get_by(TOTP, user_id: user_id)
  end
end
