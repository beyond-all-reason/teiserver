defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}

  @spec get_user_totp(User.t()) :: {:active, TOTP.t()} | {:inactive, nil}
  defp get_user_totp(%User{id: nil}) do
    {:inactive, nil}
  end

  defp get_user_totp(%User{id: user_id}) do
    case Repo.get_by(TOTP, user_id: user_id) do
      nil ->
        {:inactive, nil}

      totp ->
        {:active, totp}
    end
  end

  @spec get_user_totp_status(User.t()) :: :active | :inactive
  def get_user_totp_status(%User{} = user) do
    {status, _totp} = get_user_totp(user)
    status
  end

  @spec get_or_generate_secret(User.t()) :: {:new | :existing, binary()}
  def get_or_generate_secret(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:new, NimbleTOTP.secret()}

      {:active, totp} ->
        {:existing, totp.secret}
    end
  end

  @spec get_user_secret(User.t()) :: binary | nil
  def get_user_secret(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        :inactive

      {:active, totp} ->
        totp.secret
    end
  end

  @spec get_last_used_otp(User.t()) :: any
  def get_last_used_otp(%User{id: _user_id} = user) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        :inactive

      {:active, totp} ->
        totp.last_used
    end
  end

  @spec set_totp(User.t() | TOTP.t(), map()) ::
          {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  defp set_totp(%User{id: nil} = _user, _attrs) do
    changeset = TOTP.changeset(%TOTP{}, %{})
    {:error, %{changeset | errors: [user: {"user must be persisted", []}]}}
  end

  defp set_totp(%User{} = user, attrs) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        TOTP.changeset(%TOTP{}, attrs)
        |> Repo.insert()

      {:active, totp} ->
        set_totp(totp, attrs)
    end
  end

  defp set_totp(%TOTP{} = totp, attrs) do
    totp
    |> TOTP.changeset(attrs)
    |> Repo.update()
  end

  @spec set_secret(User.t(), binary) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def set_secret(%User{} = user, secret) do
    set_totp(user, %{user_id: user.id, secret: secret})
  end

  @spec set_last_used(User.t(), String.t()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def set_last_used(%User{} = user, last_used) do
    set_totp(user, %{user_id: user.id, last_used: last_used})
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

  @spec validate_totp(User.t() | binary, String.t()) ::
          {:ok, :valid | :grace} | {:error, :inactive | :invalid | :used}
  def validate_totp(%User{id: _user_id} = user, otp) do
    case get_user_totp(user) do
      {:inactive, nil} ->
        {:error, :inactive}

      {:active, totp} ->
        if validate_last_used(totp.last_used, otp) do
          {:error, :used}
        else
          case validate_totp(totp.secret, otp) do
            {:ok, info} ->
              set_last_used(user, otp)
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

  @spec validate_last_used(String.t(), String.t()) :: boolean
  def validate_last_used(last_used, otp) do
    last_used == otp
  end
end
