defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}

  @spec validate_totp(User.t(), String.t()) :: any
  def validate_totp(%User{id: _user_id} = user, otp) do
    now = System.os_time(:second)

    case get_user_totp(user) do
      {:inactive, nil} ->
        {:error, :inactive}

      {:active, totp} ->
        cond do
          validate_last_used(totp, otp) ->
            {:error, :used}

          NimbleTOTP.valid?(totp.secret, otp, time: now) ->
            change_totp(totp, %{last_used: otp})
            {:ok, :valid}

          NimbleTOTP.valid?(totp.secret, otp, time: System.os_time(:second) - 5) ->
            change_totp(totp, %{last_used: otp})
            {:ok, :grace}

          true ->
            {:error, :invalid}
        end
    end
  end

  @spec validate_last_used(TOTP.t(), String.t()) :: boolean
  def validate_last_used(%TOTP{last_used: last_used}, otp) do
    last_used == otp
  end

  @spec get_or_generate_user_secret(User.t()) :: binary()
  def get_or_generate_user_secret(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:ok, totp} = generate_secret(user)
        totp.secret

      {:active, totp} ->
        totp.secret
    end
  end

  @spec generate_secret(User.t()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  defp generate_secret(%User{id: user_id} = user) do
    secret = NimbleTOTP.secret()

    case get_user_totp(user) do
      {:inactive, nil} ->
        %TOTP{}
        |> TOTP.changeset(%{user_id: user_id, secret: secret})
        |> Repo.insert()

      {:active, totp} ->
        totp
        |> TOTP.changeset(%{secret: secret})
        |> Repo.update()
    end
  end

  @spec get_user_totp(User.t()) :: {:ok | :inactive, TOTP.t() | nil}
  def get_user_totp(%User{id: user_id}) do
    case Repo.get_by(TOTP, user_id: user_id) do
      nil ->
        {:inactive, nil}

      totp ->
        {:active, totp}
    end
  end

  @spec change_totp(User.t() | TOTP.t(), Map.t()) ::
          {:ok, TOTP.t()} | {:error, nil | Ecto.Changeset.t()}
  def change_totp(%User{} = user, attrs) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:error, nil}

      {:active, totp} ->
        change_totp(totp, attrs)
    end
  end

  def change_totp(%TOTP{} = totp, attrs) do
    totp
    |> TOTP.changeset(attrs)
    |> Repo.update()
  end
end
