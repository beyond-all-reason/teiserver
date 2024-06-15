defmodule Teiserver.OAuth do
  alias Teiserver.Repo
  alias Teiserver.OAuth.{Application, Code, Token, ApplicationQueries, CodeQueries, TokenQueries}
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

  @spec get_application_by_uid(Application.app_id()) :: Application.t() | nil
  defdelegate get_application_by_uid(uid), to: ApplicationQueries

  @doc """
  Given an application and a potential encoded redirect_uri, decode the uri
  and validate it against the registered redirect uris for the application.
  """
  @spec get_redirect_uri(Application.t(), String.t()) :: {:ok, URI.t()} | {:error, term()}
  def get_redirect_uri(app, encoded_uri) do
    parsed = encoded_uri |> URI.decode_www_form() |> URI.parse()

    # https://www.rfc-editor.org/rfc/rfc6749.html#section-3.1.2
    cond do
      not is_nil(parsed.fragment) -> {:error, "Fragment must not be included"}
      Enum.any?(app.redirect_uris, fn app_uri -> equal_uri?(app_uri, parsed) end) -> {:ok, parsed}
      true -> {:error, "No matching redirect uri found"}
    end
  end

  # Compares two uris, but only the scheme, host and path.
  # Redirect URI for oauth application shouldn't have query string, and the client
  # can add some which must be preserved.
  # If the host is localhost, either "localhost", the ipv4 or ipv6 notations are allowed
  # If the host is localhost, the port isn't compared since client have the freedom
  # of choosing it (usually it's whatever they can bind).
  defp equal_uri?(%URI{} = uri1, %URI{} = uri2) do
    cond do
      uri1.scheme != uri2.scheme || uri1.path != uri2.path ->
        false

      localhost?(uri1) and localhost?(uri2) ->
        true

      not localhost?(uri1) and not localhost?(uri2) ->
        uri1.host == uri2.host && uri1.port == uri2.port

      # one is localhost while the other isn't
      true ->
        false
    end
  end

  defp equal_uri?(uri1, uri2) do
    equal_uri?(URI.parse(uri1), uri2)
  end

  # https://www.rfc-editor.org/rfc/rfc8252#section-7.3
  # although `localhost` is not recommended, it is allowed, see:
  # and https://www.rfc-editor.org/rfc/rfc8252#section-8.3
  defp localhost?(%URI{} = uri), do: localhost?(uri.host)
  defp localhost?("localhost"), do: true
  defp localhost?("127.0.0.1"), do: true
  defp localhost?("::1"), do: true
  defp localhost?("0:0:0:0:0:0:0:1"), do: true
  defp localhost?(_), do: false

  @doc """
  Create an authorization token for the given user and application.
  The token scopes are the same as the application
  """
  @spec create_code(
          User.t() | T.userid(),
          %{
            id: integer(),
            scopes: Application.scopes(),
            redirect_uri: String.t(),
            challenge: String.t(),
            challenge_method: String.t()
          },
          options()
        ) ::
          {:ok, Code.t()} | {:error, Ecto.Changeset.t()}
  def create_code(user, attrs, opts \\ [])

  def create_code(%User{} = user, attrs, opts) do
    create_code(user.id, attrs, opts)
  end

  def create_code(user, attrs, opts) when is_map(user) do
    create_code(user.id, attrs, opts)
  end

  def create_code(user_id, attrs, opts) do
    now = Keyword.get(opts, :now, Timex.now())

    # don't do any validation on the challenge yet, this is done when exchanging
    # the code for a token
    attrs = %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32)),
      owner_id: user_id,
      application_id: attrs.id,
      scopes: attrs.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_minutes(5)),
      redirect_uri: Map.get(attrs, :redirect_uri),
      challenge: Map.get(attrs, :challenge),
      challenge_method: Map.get(attrs, :challenge_method)
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

  @spec create_token(
          User.t() | T.userid(),
          %{id: integer(), scopes: Application.scopes()},
          options()
        ) ::
          {:ok, Token.t()} | {:error, Ecto.Changeset.t()}
  def create_token(user_id, application, opts \\ [])

  def create_token(%User{} = user, application, opts) do
    create_token(user.id, application, opts)
  end

  def create_token(user, application, opts) when is_map(user) do
    create_token(user.id, application, opts)
  end

  def create_token(user_id, application, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())

    refresh_attrs = %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32), padding: false),
      owner_id: user_id,
      application_id: application.id,
      scopes: application.scopes,
      # there's no real recourse when the refresh token expires and it's
      # quite annoying, so make it "never" expire.
      expires_at: Timex.add(now, Timex.Duration.from_days(365 * 100)),
      type: :refresh,
      refresh_token: nil
    }

    token_attrs = %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32), padding: false),
      owner_id: user_id,
      application_id: application.id,
      scopes: application.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_minutes(30)),
      type: :bearer,
      refresh_token: refresh_attrs
    }

    %Token{}
    |> Token.changeset(token_attrs)
    |> Repo.insert()
  end

  # TODO: get_valid_token is basically the same as get_valid_code, refactor later

  @doc """
  Given a code returns the corresponding db object, making sure
  it is valid (exists, not expired, not revoked)
  """
  @spec get_valid_token(String.t(), options()) :: {:ok, Token.t()} | {:error, term()}
  def get_valid_token(value, opts \\ [])

  def get_valid_token(value, opts) do
    case TokenQueries.get_token(value) do
      nil ->
        {:error, :no_token}

      token ->
        now = Keyword.get(opts, :now, Timex.now())

        if Timex.after?(now, token.expires_at) do
          {:error, :expired}
        else
          {:ok, token}
        end
    end
  end

  @doc """
  Given an authorization code, creates and return an authentication token
  (and its associated refresh token).
  """
  @spec exchange_code(Code.t(), String.t(), String.t() | nil, options()) ::
          {:ok, Token.t()} | {:error, term()}
  def exchange_code(code, verifier, redirect_uri \\ nil, opts \\ []) do
    now = Keyword.get(opts, :now, Timex.now())

    cond do
      expired?(code, now) ->
        {:error, :expired}

      code.redirect_uri != redirect_uri ->
        {:error, :redirect_uri_mismatch}

      not code_verified?(code, verifier) ->
        {:error, :code_verification_failed}

      true ->
        Repo.transaction(fn ->
          Repo.delete!(code)

          {:ok, token} =
            create_token(code.owner_id, %{id: code.application_id, scopes: code.scopes}, opts)

          token
        end)
    end
  end

  @spec code_verified?(Code.t(), String.t()) :: boolean()
  defp code_verified?(%Code{challenge_method: :plain, challenge: challenge}, verifier) do
    valid_verifier?(verifier) and :crypto.hash_equals(challenge, verifier)
  end

  defp code_verified?(%Code{challenge_method: :S256, challenge: challenge}, verifier) do
    with true <- valid_verifier?(verifier),
         {:ok, challenge} <- Base.url_decode64(challenge, padding: false, ignore: :whitespace) do
      hashed_verifier = :crypto.hash(:sha256, verifier)
      :crypto.hash_equals(challenge, hashed_verifier)
    else
      _ ->
        false
    end
  end

  defp code_verified?(_, _), do: false

  # A-Z, a-z, 0-9, and the punctuation characters -._~
  defp valid_verifier?(verifier) do
    s = byte_size(verifier)
    43 <= s and s <= 128 and String.match?(verifier, ~r/[A-Za-z0-9\-._~]/)
  end

  @spec refresh_token(Token.t(), options()) :: {:ok, Token.t()} | {:error, term()}
  def refresh_token(token, opts \\ [])

  def refresh_token(token, _opts) when token.type != :refresh do
    {:error, :invalid_token}
  end

  def refresh_token(token, opts) do
    now = Keyword.get(opts, :now, Timex.now())

    if expired?(token, now) do
      {:error, :expired}
    else
      token =
        if Ecto.assoc_loaded?(token.application) do
          token
        else
          TokenQueries.get_token(token.value)
        end

      Repo.transaction(fn ->
        {:ok, new_token} = create_token(token.owner_id, token.application, opts)
        TokenQueries.delete_refresh_token(token)
        new_token
      end)
    end
  end

  defp expired?(obj, now) do
    Timex.after?(now, Map.fetch!(obj, :expires_at))
  end
end
