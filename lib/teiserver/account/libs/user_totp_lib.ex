defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}

  @spec validate_totp(User.t() | binary, String.t()) ::
          {:ok, :valid | :grace} | {:error, :inactive | :invalid | :used}
  def validate_totp(%User{id: _user_id} = user, otp) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:error, :inactive}

      {:active, totp} ->
        if validate_last_used(totp, otp) do
          {:error, :used}
        else
          # Validates OTP against the secret
          case validate_totp(totp.secret, otp) do
            # Update last_used if OTP tested successful
            {:ok, info} ->
              set_totp(totp, %{last_used: otp})
              {:ok, info}

            {:error, :invalid} ->
              {:error, :invalid}
          end
        end
    end
  end

  def validate_totp(secret, otp) do
    now = System.os_time(:second)

    cond do
      NimbleTOTP.valid?(secret, otp, time: now) ->
        {:ok, :valid}

      NimbleTOTP.valid?(secret, otp, time: now - 5) ->
        {:ok, :grace}

      true ->
        {:error, :invalid}
    end
  end

  @spec validate_last_used(TOTP.t(), String.t()) :: boolean
  def validate_last_used(%TOTP{last_used: last_used}, otp) do
    last_used == otp
  end

  #  Todo:
  #  - Function that either gets the secret from the user, or generates a new secret and returns it (get_or_generate_secret) [Done]
  #  - Function to generate a new secret for the user (reset_secret) [done]
  #  - Function to set the secret for a user, if none exists (possibly_activate_2FA) [done]
  #  - Function to delete the whole TOTP row for a user (deactivate_2FA) [done]

  @spec get_or_generate_secret(User.t()) :: {:new | :existing, binary()}
  def get_or_generate_secret(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:new, NimbleTOTP.secret()}

      {:active, totp} ->
        {:existing, totp.secret}
    end
  end

  @spec reset_secret(User.t()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def reset_secret(%User{} = user) do
    secret = NimbleTOTP.secret()
    set_totp(user, %{secret: secret})
  end

  @spec set_secret(User.t(), String.t()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def set_secret(%User{} = user, secret) do
    set_totp(user, %{user_id: user.id, secret: secret})
  end

  @spec disable_totp(User.t()) :: {:ok, TOTP.t() | nil} | {:error, Ecto.Changeset.t()}
  def disable_totp(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:active, totp} ->
        Repo.delete(totp)

      {:inactive, _} ->
        {:ok, nil}
    end
  end

  @spec get_user_totp(User.t()) :: {:active, TOTP.t()} | {:inactive, nil}
  def get_user_totp(%User{id: user_id}) do
    case Repo.get_by(TOTP, user_id: user_id) do
      nil ->
        {:inactive, nil}

      totp ->
        {:active, totp}
    end
  end

  @spec set_totp(User.t() | TOTP.t(), Map.t()) ::
          {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def set_totp(%User{} = user, attrs) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        TOTP.changeset(%TOTP{}, attrs)
        |> Repo.insert()

      {:active, totp} ->
        set_totp(totp, attrs)
    end
  end

  def set_totp(%TOTP{} = totp, attrs) do
    totp
    |> TOTP.changeset(attrs)
    |> Repo.update()
  end
end
