defmodule Teiserver.OAuthFixtures do
  alias Teiserver.OAuth.{Application, Code, Token, Credential}
  alias Teiserver.Repo

  def app_attrs(owner_id) do
    %{
      name: "fixture app",
      uid: "fixture_app",
      owner_id: owner_id,
      scopes: ["tachyon.lobby"],
      redirect_uris: ["http://localhost/foo"],
      description: "app created as part of a test"
    }
  end

  def create_app(attrs) do
    %Application{} |> Application.changeset(attrs) |> Repo.insert!()
  end

  def update_app(app, changes) do
    Ecto.Changeset.change(app, changes) |> Repo.update!()
  end

  def code_attrs(user_id, app) do
    now = DateTime.utc_now()
    {verifier, challenge, method} = generate_challenge()

    %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32)),
      owner_id: user_id,
      application_id: app.id,
      scopes: app.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_minutes(5)),
      redirect_uri: List.first(app.redirect_uris),
      challenge: challenge,
      challenge_method: method,
      _verifier: verifier
    }
  end

  def create_code(attrs) do
    %Code{} |> Code.changeset(attrs) |> Repo.insert!()
  end

  def token_attrs(user_id, application) do
    now = DateTime.utc_now()

    %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32), padding: false),
      owner_id: user_id,
      application_id: application.id,
      scopes: application.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_days(60)),
      type: :access,
      refresh_token: nil
    }
  end

  def create_token(attrs) do
    %Token{} |> Token.changeset(attrs) |> Repo.insert!()
  end

  def credential_attrs(bot, app_id) do
    %{
      application_id: app_id,
      bot_id: bot.id,
      client_id: UUID.uuid4(),
      hashed_secret: UUID.uuid4()
    }
  end

  def create_credential(attrs) do
    %Credential{} |> Credential.changeset(attrs) |> Repo.insert!()
  end

  @doc """
  given a user id, will create a OAuth application and a valid token for that
  user, returning both
  """
  def setup_token(user_or_id, opts \\ [])
  def setup_token(%{user: user}, opts), do: setup_token(user.id, opts)
  def setup_token(%{id: id}, opts), do: setup_token(id, opts)

  def setup_token(user_id, opts) do
    app =
      app_attrs(user_id)
      |> Map.update!(:scopes, fn s -> Keyword.get(opts, :scopes, s) end)
      |> create_app()

    token = token_attrs(user_id, app) |> create_token()
    %{app: app, token: token}
  end

  defp generate_challenge() do
    # A-Z,a-z,0-9 and -._~ are authorized, but can't be bothered to cover all
    # of that. hex encoding will fit
    # hardcoded random bytes generated with :crypto.strong_rand_bytes(32)
    bytes =
      <<30, 33, 141, 180, 13, 27, 42, 190, 106, 230, 111, 140, 162, 230, 128, 110, 149, 65, 33,
        124, 129, 9, 89, 93, 94, 248, 46, 34, 116, 186, 8, 24>>

    verifier = Base.hex_encode32(bytes, padding: false)
    challenge = hash_verifier(verifier)

    {verifier, challenge, "S256"}
  end

  def hash_verifier(verifier),
    do: Base.url_encode64(:crypto.hash(:sha256, verifier), padding: false)
end
