defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}
  alias Teiserver.Data.Types, as: T

  @otp_grace_time 5
  @allowed_invalid_attempts 5

  @spec get_user_totp(T.userid()) :: {:inactive, nil} | {:active, TOTP.t()}
  defp get_user_totp(user_id) do
    case Repo.get_by(TOTP, user_id: user_id) do
      nil ->
        {:inactive, nil}

      totp ->
        {:active, totp}
    end
  end

  @spec get_user_totp_status(T.userid() | TOTP.t()) :: :active | :inactive
  def get_user_totp_status(user_id) do
    {status, _totp} = get_user_totp(user_id)
    status
  end

  @spec get_account_locked(T.userid()) :: boolean()
  def get_account_locked(user_id) do
    {_status, totp} = get_user_totp(user_id)

    cond do
      is_nil(totp) ->
        false

      totp.wrong_otp < @allowed_invalid_attempts ->
        false

      totp.wrong_otp >= @allowed_invalid_attempts ->
        true
    end
  end

  @spec get_or_generate_secret(T.userid()) :: {:new | :existing, binary()}
  def get_or_generate_secret(user_id) do
    case get_user_totp(user_id) do
      {:inactive, nil} ->
        {:new, NimbleTOTP.secret()}

      {:active, totp} ->
        {:existing, totp.secret}
    end
  end

  @spec get_user_secret(T.userid()) :: :inactive | binary() | nil
  def get_user_secret(user_id) do
    case get_user_totp(user_id) do
      {:inactive, nil} ->
        :inactive

      {:active, totp} ->
        totp.secret
    end
  end

  @spec get_last_used_otp(T.userid()) :: :inactive | DateTime.t()
  def get_last_used_otp(user_id) do
    case get_user_totp(user_id) do
      {:inactive, nil} ->
        :inactive

      {:active, totp} ->
        totp.last_used
    end
  end

  @spec set_totp(TOTP.t() | T.userid() | nil, map()) ::
          {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  defp set_totp(nil, _attrs) do
    changeset = TOTP.changeset(%TOTP{}, %{})
    {:error, %{changeset | errors: [user: {"user must be persisted", []}]}}
  end

  defp set_totp(%TOTP{} = totp, attrs) do
    totp
    |> TOTP.changeset(attrs)
    |> Repo.update()
  end

  defp set_totp(user_id, attrs) do
    case get_user_totp(user_id) do
      {:inactive, nil} ->
        TOTP.changeset(%TOTP{}, attrs)
        |> Repo.insert()

      {:active, totp} ->
        set_totp(totp, attrs)
    end
  end

  @spec set_secret(T.userid(), binary()) :: {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()}
  def set_secret(user_id, secret) do
    set_totp(user_id, %{user_id: user_id, secret: secret})
  end

  @spec set_last_used(T.userid(), integer()) ::
          {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()} | {:inactive, User.t()}
  def set_last_used(user_id, last_used) do
    if get_user_totp_status(user_id) == :active do
      {:ok, utc_datetime} = DateTime.from_unix(last_used, :second)

      case set_totp(user_id, %{user_id: user_id, last_used: utc_datetime}) do
        {:ok, _} ->
          :ok

        {:error, changeset} ->
          {:error, changeset}
      end
    else
      :inactive
    end
  end

  @spec disable_totp(T.userid()) :: :ok | :error
  def disable_totp(user_id) do
    case get_user_totp(user_id) do
      {:active, totp} ->
        case Repo.delete(totp) do
          {:ok, _} ->
            :ok

          {:error, changeset} ->
            {:error, changeset}
        end

      {:inactive, _} ->
        :ok
    end
  end

  defp increase_wrong_otp_counter(%TOTP{} = totp) do
    from(t in TOTP, where: t.user_id == ^totp.user_id)
    |> Repo.update_all(inc: [wrong_otp: 1])
  end

  def reset_wrong_otp_counter(totp) do
    from(t in TOTP, where: t.user_id == ^totp.user_id)
    |> Repo.update_all(set: [wrong_otp: 0])
  end

  def validate_totp(user_or_secret, otp, time \\ System.os_time(:second))

  @spec validate_totp(User.t(), String.t(), integer()) ::
          {:ok, :valid | :grace} | {:error, :inactive | :invalid | :used | :locked}
  def validate_totp(%User{id: user_id}, otp, time) do
    {status, totp} = get_user_totp(user_id)

    with :active <- status,
         false <- get_account_locked(user_id),
         {:ok, info} <- validate_totp(totp.secret, otp, time, since: totp.last_used) do
      case info do
        :valid ->
          set_last_used(user_id, time)

        :grace ->
          set_last_used(user_id, time - @otp_grace_time)
      end

      reset_wrong_otp_counter(totp)
      :ok
    else
      :inactive ->
        {:error, :inactive}

      true ->
        {:error, :locked}

      {:error, status} ->
        if status == :invalid do
          increase_wrong_otp_counter(totp)
        else
          reset_wrong_otp_counter(totp)
        end

        {:error, status}
    end
  end

  def validate_totp(secret, otp, time) do
    cond do
      NimbleTOTP.valid?(secret, otp, time: time) ->
        {:ok, :valid}

      NimbleTOTP.valid?(secret, otp, time: time - @otp_grace_time) ->
        {:ok, :grace}

      true ->
        {:error, :invalid}
    end
  end

  @spec validate_totp(binary(), String.t(), integer(), keyword()) ::
          {:ok, :valid | :grace} | {:error, :invalid | :used}
  defp validate_totp(secret, otp, time, since: nil) do
    validate_totp(secret, otp, time)
  end

  defp validate_totp(secret, otp, time, since: last_used) do
    cond do
      NimbleTOTP.valid?(secret, otp, time: time, since: last_used) ->
        {:ok, :valid}

      NimbleTOTP.valid?(secret, otp, time: time - @otp_grace_time, since: last_used) ->
        {:ok, :grace}

      true ->
        # Second test is needed. If :since is provided and NimbleTOTP.valid? returns false, it could either be that the OTP is wrong, or that it got used.
        # To figure out which one it is, we need to test a second time without since, as a false this time indicates that the OTP is invalid, and a True that it got used
        case validate_totp(secret, otp, time) do
          {:error, :invalid} ->
            {:error, :invalid}

          _ ->
            {:error, :used}
        end
    end
  end

  @spec generate_otpauth_uri(String.t(), binary()) :: String.t()
  def generate_otpauth_uri(name, secret) do
    NimbleTOTP.otpauth_uri("BAR:#{name}", secret, issuer: "Beyond All Reason")
  end
end
