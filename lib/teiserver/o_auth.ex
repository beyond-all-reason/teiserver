defmodule Teiserver.OAuth do
  alias Teiserver.Repo
  alias Teiserver.OAuth.{Application, Code, ApplicationQueries, CodeQueries}
  alias Teiserver.Account.User
  alias Teiserver.Data.Types, as: T

  def create_application(attrs \\ %{}) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  @spec delete_application(Application.t()) :: :ok | {:error, term()}
  def delete_application(app) do
    case Repo.delete(app) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  @type option :: {:now, DateTime.t()}
  @type options :: [option]

  @doc """
  Create an authorization token for the given user and application.
  The token scopes are the same as the application
  """
  @spec create_code(User.t() | T.userid(), Application.t(), options()) ::
          {:ok, Code.t()} | {:error, Ecto.Changeset.t()}
  def create_code(user, application, opts \\ [])

  def create_code(%User{} = user, application, opts) do
    create_code(user.id, application, opts)
  end

  def create_code(user, application, opts) when is_map(user) do
    create_code(user.id, application, opts)
  end

  def create_code(user_id, application, opts) do
    now = Keyword.get(opts, :now, Timex.now())

    attrs = %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32)),
      owner_id: user_id,
      application_id: application.id,
      scopes: application.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_minutes(5))
    }

    %Code{}
    |> Code.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Given a code returns the corresponding db object, making sure
  it is valid (exists, not expired, not revoked)
  """
  @spec get_valid_code(String.t(), options()) :: {:ok, Code.t()} | {:error, term()}
  def get_valid_code(code, opts \\ [])

  def get_valid_code(code, opts) do
    case CodeQueries.get_code(code) do
      nil ->
        {:error, :no_code}

      code ->
        now = Keyword.get(opts, :now, Timex.now())

        if expired?(code, now) do
          {:error, :expired}
        else
          {:ok, code}
        end
    end
  end

  @spec get_application_by_uid(Application.app_id()) :: Application.t() | nil
  defdelegate get_application_by_uid(uid), to: ApplicationQueries

  defp expired?(obj, now) do
    Timex.after?(now, Map.fetch!(obj, :expires_at))
  end
end
