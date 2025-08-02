defmodule Teiserver.OAuth do
  alias Teiserver.Repo

  alias Teiserver.Bot.Bot

  alias Teiserver.OAuth.{
    Application,
    Code,
    Token,
    Credential,
    ApplicationQueries,
    CodeQueries,
    TokenQueries,
    CredentialQueries
  }

  alias Teiserver.Account.User
  alias Teiserver.Data.Types, as: T

  # @spec change_application(Application.t(), map() | nil) :: Ecto.Changeset
  def change_application(%Application{} = app, attrs \\ %{}) do
    Application.changeset(app, attrs)
  end

  def create_application(attrs \\ %{}) do
    %Application{}
    |> Application.changeset(attrs)
    |> Repo.insert()
  end

  def update_application(%Application{} = app, attrs) do
    app |> change_application(attrs) |> Repo.update()
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
  Some applications are not meant to allow authorization code grants
  typically the ones meant for bots
  """
  @spec can_create_code?(Application.t()) :: boolean()
  def can_create_code?(%Application{} = app) do
    ApplicationQueries.application_allows_code?(app)
  end

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
          {:ok, Code.t()} | {:error, Ecto.Changeset.t() | :invalid_flow}
  def create_code(user, attrs, opts \\ [])

  def create_code(%User{} = user, attrs, opts) do
    create_code(user.id, attrs, opts)
  end

  def create_code(user, attrs, opts) when is_map(user) do
    create_code(user.id, attrs, opts)
  end

  def create_code(user_id, attrs, opts) do
    now = Keyword.get(opts, :now, Timex.now())
    app_id = attrs.id

    if ApplicationQueries.application_allows_code?(app_id) do
      # don't do any validation on the challenge yet, this is done when exchanging
      # the code for a token
      attrs = %{
        value: Base.hex_encode32(:crypto.strong_rand_bytes(32)),
        owner_id: user_id,
        application_id: app_id,
        scopes: attrs.scopes,
        expires_at: Timex.add(now, Timex.Duration.from_minutes(5)),
        redirect_uri: Map.get(attrs, :redirect_uri),
        challenge: Map.get(attrs, :challenge),
        challenge_method: Map.get(attrs, :challenge_method)
      }

      %Code{}
      |> Code.changeset(attrs)
      |> Repo.insert()
    else
      {:error, :invalid_flow}
    end
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
        check_expiry(code, now)
    end
  end

  @spec create_token(
          User.t() | T.userid(),
          %{
            :id => integer(),
            :scopes => Application.scopes(),
            optional(:original_scopes) => Application.scopes()
          },
          create_refresh: boolean() | options(),
          scopes: Application.scopes()
        ) ::
          {:ok, Token.t()} | {:error, :invalid_scope | Ecto.Changeset.t()}
  def create_token(user_id, application, opts \\ [])

  def create_token(%User{} = user, application, opts) do
    create_token(user.id, application, opts)
  end

  def create_token(user, application, opts) when is_map(user) do
    create_token(user.id, application, opts)
  end

  def create_token(user_id, application, opts) do
    do_create_token(%{owner_id: user_id}, application, opts)
  end

  defp do_create_token(owner_attr, application, opts) do
    now = Keyword.get(opts, :now, DateTime.utc_now())
    scopes = opts[:scopes]

    if Enum.empty?(scopes) ||
         not MapSet.subset?(MapSet.new(scopes), MapSet.new(application.scopes)) do
      {:error, :invalid_scope}
    else
      token_attrs =
        %{
          value: Base.hex_encode32(:crypto.strong_rand_bytes(32), padding: false),
          application_id: application.id,
          scopes: scopes,
          original_scopes: Map.get(application, :original_scopes, application.scopes),
          expires_at: Timex.add(now, Timex.Duration.from_minutes(30)),
          type: :access
        }
        |> Map.merge(owner_attr)

      refresh_attrs =
        if Keyword.get(opts, :create_refresh, true) do
          %{
            value: Base.hex_encode32(:crypto.strong_rand_bytes(32), padding: false),
            application_id: application.id,
            scopes: scopes,
            original_scopes: application.scopes,
            # there's no real recourse when the refresh token expires and it's
            # quite annoying, so make it "never" expire.
            expires_at: Timex.add(now, Timex.Duration.from_days(365 * 100)),
            type: :refresh,
            refresh_token: nil
          }
          |> Map.merge(owner_attr)
        else
          nil
        end

      token_attrs = Map.put(token_attrs, :refresh_token, refresh_attrs)

      %Token{}
      |> Token.changeset(token_attrs)
      |> Repo.insert()
    end
  end

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
        check_expiry(token, now)
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

    with {:ok, code} <- check_expiry(code, now),
         :ok <-
           if(code.redirect_uri == redirect_uri, do: :ok, else: {:error, :redirect_uri_mismatch}),
         :ok <- check_verifier(code, verifier) do
      Repo.transaction(fn ->
        Repo.delete!(code)

        {:ok, token} =
          create_token(
            code.owner_id,
            %{id: code.application_id, scopes: code.scopes},
            Keyword.put(opts, :scopes, code.scopes)
          )

        token
      end)
    end
  end

  @spec check_verifier(Code.t(), String.t()) :: :ok | {:error, term()}
  defp check_verifier(%Code{challenge_method: :plain, challenge: challenge}, verifier) do
    with :ok <- valid_verifier(verifier) do
      compare_hash(challenge, verifier)
    end
  end

  defp check_verifier(%Code{challenge_method: :S256, challenge: challenge}, verifier) do
    with :ok <- valid_verifier(verifier),
         {:ok, challenge} <- Base.url_decode64(challenge, padding: false, ignore: :whitespace),
         :ok <-
           compare_hash(challenge, :crypto.hash(:sha256, verifier)) do
      :ok
    end
  end

  defp check_verifier(_, _), do: {:error, :invalid_verifier}

  # A-Z, a-z, 0-9, and the punctuation characters -._~
  defp valid_verifier(verifier) do
    s = byte_size(verifier)

    cond do
      s < 43 ->
        {:error, "verifier cannot be less than 43 chars"}

      s > 128 ->
        {:error, "verifier cannot be more than 128 chars"}

      not String.match?(verifier, ~r/[A-Za-z0-9\-._~]/) ->
        {:error, "verifier contains illegal characters"}

      true ->
        :ok
    end
  end

  defp compare_hash(challenge, verifier) do
    cond do
      String.length(challenge) != String.length(verifier) ->
        {:error, "challenge and verifier length mismatch"}

      not :crypto.hash_equals(challenge, verifier) ->
        {:error, "verifier doesn't match challenge"}

      true ->
        :ok
    end
  end

  @spec refresh_token(Token.t(), [option() | {:scopes, Application.scopes()}]) ::
          {:ok, Token.t()} | {:error, term()}
  def refresh_token(token, opts \\ [])

  def refresh_token(token, _opts) when token.type != :refresh do
    {:error, :invalid_token}
  end

  def refresh_token(token, opts) do
    now = Keyword.get(opts, :now, Timex.now())

    case check_expiry(token, now) do
      {:error, :expired} ->
        {:error, :expired}

      _ ->
        token =
          if Ecto.assoc_loaded?(token.application) do
            token
          else
            TokenQueries.get_token(token.value)
          end

        scopes = Keyword.get(opts, :scopes, token.scopes)

        refresh_attr = %{
          id: token.application.id,
          scopes: scopes,
          original_scopes: token.original_scopes
        }

        tx_result =
          Repo.transaction(fn ->
            with {:ok, new_token} <-
                   create_token(token.owner_id, refresh_attr, Keyword.put(opts, :scopes, scopes)) do
              TokenQueries.delete_refresh_token(token)
              new_token
            end
          end)

        case tx_result do
          {:ok, {:error, err}} -> {:error, err}
          other -> other
        end
    end
  end

  @doc """
  Given a client_id, an application/app_id a bot/id and a cleartext secret, hash and persist it
  """
  @spec create_credentials(
          Application.t() | Application.app_id(),
          Bot.t() | Bot.id(),
          String.t(),
          String.t()
        ) ::
          {:ok, Credential.t()} | {:error, term()}
  def create_credentials(%Application{} = app, bot, client_id, secret),
    do: create_credentials(app.id, bot, client_id, secret)

  def create_credentials(app_id, %Bot{} = bot, client_id, secret),
    do: create_credentials(app_id, bot.id, client_id, secret)

  def create_credentials(app_id, bot_id, client_id, secret) do
    attrs = %{
      application_id: app_id,
      bot_id: bot_id,
      client_id: client_id,
      hashed_secret: Argon2.hash_pwd_salt(secret)
    }

    result =
      %Credential{}
      |> Credential.changeset(attrs)
      |> Repo.insert()

    case result do
      {:ok, cred} -> {:ok, Repo.preload(cred, :application)}
      err -> err
    end
  end

  @spec delete_credential(Credential.t() | Credential.id()) :: :ok | {:error, term()}
  def delete_credential(%Credential{} = cred) do
    case Repo.delete(cred) do
      {:ok, _} -> :ok
      {:error, err} -> {:error, err}
    end
  end

  @doc """
  Given a client_id and a cleartext secret, check the secret matches and returns the credentials
  """
  @spec get_valid_credentials(String.t(), String.t()) ::
          {:ok, Credential.t()} | {:error, term()}
  def get_valid_credentials(client_id, secret) do
    case CredentialQueries.get_credential(client_id) do
      nil ->
        # Treat client_id as "secret" so force a fake computation to avoid
        # timing attack
        Argon2.no_user_verify()
        {:error, :invalid_client_id}

      credential ->
        if Argon2.verify_pass(secret, credential.hashed_secret) do
          {:ok, credential}
        else
          {:error, :invalid_password}
        end
    end
  end

  @spec get_token_from_credentials(Credential.t(), Application.scopes()) ::
          {:ok, Token.t()} | {:error, term()}
  def get_token_from_credentials(credential, scopes) do
    do_create_token(%{bot_id: credential.bot_id}, credential.application,
      create_refresh: false,
      scopes: scopes
    )
  end

  @doc """
  Delete all expired oauth code.
  """
  @spec delete_expired_codes(DateTime.t() | nil) :: non_neg_integer()
  def delete_expired_codes(now \\ nil) do
    now = now || DateTime.utc_now()
    {count, _} = CodeQueries.base_query() |> CodeQueries.expired(now) |> Repo.delete_all()
    count
  end

  @doc """
  Delete all expired oauth tokens (access and refresh)
  """
  @spec delete_expired_tokens(DateTime.t() | nil) :: non_neg_integer()
  def delete_expired_tokens(now \\ nil) do
    now = now || DateTime.utc_now()
    {count, _} = TokenQueries.base_query() |> TokenQueries.expired(now) |> Repo.delete_all()
    count
  end

  # Because OAuth does some special basic auth handling, see:
  # https://datatracker.ietf.org/doc/html/rfc6749#section-2.3.1
  # and especially the Appendix B:
  # https://datatracker.ietf.org/doc/html/rfc6749#appendix-B
  @doc """
  Similar to Plug.BasicAuth.encode_basic_auth but compliant with OAuth special handling
  Takes client id, client secret and returns the basic auth header
  """
  @spec encode_basic_auth(String.t(), String.t()) :: String.t()
  def encode_basic_auth(client_id, client_secret) do
    encoded =
      Base.encode64("#{URI.encode_www_form(client_id)}:#{URI.encode_www_form(client_secret)}")

    "Basic #{encoded}"
  end

  @doc """
  Similar to Plug.BasicAuth.parse_basic_auth but compliant with OAuth special handling
  """
  @spec parse_basic_auth(Plug.Conn.t()) ::
          {client_id :: String.t(), client_secret :: String.t()} | :error
  def parse_basic_auth(%Plug.Conn{} = conn) do
    with ["Basic " <> encoded_parts] <- Plug.Conn.get_req_header(conn, "authorization"),
         {:ok, decoded} <- Base.decode64(encoded_parts),
         [client_id, client_secret] <- :binary.split(decoded, ":") do
      {URI.decode_www_form(client_id), URI.decode_www_form(client_secret)}
    else
      _ -> :error
    end
  end

  defp check_expiry(obj, now) do
    if Timex.after?(now, Map.fetch!(obj, :expires_at)) do
      {:error, :expired}
    else
      {:ok, obj}
    end
  end
end
