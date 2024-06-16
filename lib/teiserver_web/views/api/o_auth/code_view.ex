defmodule TeiserverWeb.OAuth.CodeView do
  use TeiserverWeb, :view

  def token(%{token: token}) do
    expires_in = DateTime.diff(token.expires_at, DateTime.utc_now(), :second)

    %{
      access_token: token.value,
      expires_in: expires_in,
      refresh_token: token.refresh_token.value,
      token_type: "Bearer"
    }
  end

  def error(conn) do
    Map.take(conn, [:error_description]) |> Map.put("error", "invalid_request")
  end

  def metadata(_) do
    base = Application.fetch_env!(:teiserver, Teiserver.OAuth)[:issuer]

    %{
      issuer: base,
      authorization_endpoint: base <> ~p"/oauth/authorize",
      token_endpoint: base <> ~p"/oauth/token",
      token_endpoint_auth_methods_supported: ["none", "client_secret_post"],
      grant_types_supported: [
        "authorization_code",
        "refresh_token",
        "client_credentials"
      ],
      code_challenge_methods_supported: ["S256"]
    }
  end
end
