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

  def code_attrs(user_id, app) do
    now = DateTime.utc_now()

    %{
      value: Base.hex_encode32(:crypto.strong_rand_bytes(32)),
      owner_id: user_id,
      application_id: app.id,
      scopes: app.scopes,
      expires_at: Timex.add(now, Timex.Duration.from_minutes(5)),
      redirect_uri: hd(app.redirect_uris),
      challenge: "TODO",
      challenge_method: :plain
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

  def credential_attrs(autohost, app_id) do
    %{
      application_id: app_id,
      autohost_id: autohost.id,
      client_id: UUID.uuid4(),
      hashed_secret: UUID.uuid4()
    }
  end

  def create_credential(attrs) do
    %Credential{} |> Credential.changeset(attrs) |> Repo.insert!()
  end
end
