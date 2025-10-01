defmodule Teiserver.Account.TOTPLib do
  use TeiserverWeb, :library
  alias Teiserver.Account.{User, TOTP}

  @grace 5

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

  @spec get_account_locked(User.t()) :: :active | :locked
  def get_account_locked(%User{} = user) do
    {_status, totp} = get_user_totp(user)

    cond do
      is_nil(totp) ->
        false

      totp.wrong_otp < 5 ->
        false

      totp.wrong_otp >= 5 ->
        true
    end
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

  @spec get_last_used_otp(User.t()) :: :inactive | NaiveDateTime.t()
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

  @spec set_last_used(User.t(), NaiveDateTime.t()) ::
          {:ok, TOTP.t()} | {:error, Ecto.Changeset.t()} | {:inactive, User.t()}
  def set_last_used(%User{} = user, last_used) do
    if get_user_totp_status(user) == :active do
      set_totp(user, %{user_id: user.id, last_used: last_used})
    else
      {:inactive, user}
    end
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

  defp increase_wrong_otp_counter(%TOTP{} = totp) do
    from(t in TOTP, where: t.user_id == ^totp.user_id)
    |> Repo.update_all(inc: [wrong_otp: 1])
  end

  def reset_wrong_otp_counter(totp) do
    from(t in TOTP, where: t.user_id == ^totp.user_id)
    |> Repo.update_all(set: [wrong_otp: 0])
  end

  def validate_totp(user_or_secret, otp, time \\ System.os_time(:second))

  @spec validate_totp(User.t(), String.t(), integer) ::
          {:ok, :valid | :grace} | {:error, :inactive | :invalid | :used | :locked}
  def validate_totp(%User{} = user, otp, time) do
    {status, totp} = get_user_totp(user)

    with :active <- status,
         false <- get_account_locked(user),
         {:ok, info} <- validate_totp(totp.secret, otp, time, since: totp.last_used) do
      last_used = time |> DateTime.from_unix!() |> DateTime.to_naive()

      case info do
        :valid ->
          set_last_used(user, last_used)

        :grace ->
          set_last_used(user, NaiveDateTime.add(last_used, -@grace, :second))
      end

      reset_wrong_otp_counter(totp)
      {:ok, info}
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

  @spec validate_totp(binary, String.t(), integer) :: {:ok, :valid | :grace} | {:error, :invalid}
  def validate_totp(secret, otp, time) do
    cond do
      NimbleTOTP.valid?(secret, otp, time: time) ->
        {:ok, :valid}

      NimbleTOTP.valid?(secret, otp, time: time - @grace) ->
        {:ok, :grace}

      true ->
        {:error, :invalid}
    end
  end

  @spec validate_totp(binary, String.t(), NaiveDateTime.t()) ::
          {:ok, :valid | :grace} | {:error, :invalid | :used}
  def validate_totp(secret, otp, time, since: last_used) do
    if is_nil(last_used) do
      validate_totp(secret, otp, time)
    else
      cond do
        NimbleTOTP.valid?(secret, otp, time: time, since: last_used) ->
          {:ok, :valid}

        NimbleTOTP.valid?(secret, otp, time: time - @grace, since: last_used) ->
          {:ok, :grace}

        true ->
          case validate_totp(secret, otp, time) do
            {:error, :invalid} ->
              {:error, :invalid}

            _ ->
              {:error, :used}
          end
      end
    end
  end

  @spec generate_otpauth_uri(String.t(), binary) :: String.t()
  def generate_otpauth_uri(name, secret) do
    NimbleTOTP.otpauth_uri("BAR:#{name}", secret, issuer: "Beyond All Reason")
  end
end
