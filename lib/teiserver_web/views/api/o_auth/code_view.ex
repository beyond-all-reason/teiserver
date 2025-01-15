defmodule TeiserverWeb.OAuth.CodeView do
  use TeiserverWeb, :view

  def token(%{token: token}) do
    expires_in = DateTime.diff(token.expires_at, DateTime.utc_now(), :second)

    %{
      access_token: token.value,
      expires_in: expires_in,
      token_type: "Bearer"
    }
    |> then(fn res ->
      case Map.get(token, :refresh_token) do
        nil -> res
        refresh_token -> Map.put(res, :refresh_token, refresh_token.value)
      end
    end)
  end

  def error(conn) do
    Map.take(conn, [:error_description]) |> Map.put("error", "invalid_request")
  end

  def metadata(_) do
    base = Application.get_env(:teiserver, Teiserver.OAuth)[:issuer] || TeiserverWeb.Endpoint.url()

    %{
      issuer: base,
      authorization_endpoint: base <> ~p"/oauth/authorize",
      token_endpoint: base <> ~p"/oauth/token",
      token_endpoint_auth_methods_supported: ["none", "client_secret_post", "client_secret_basic"],
      grant_types_supported: [
        "authorization_code",
        "refresh_token",
        "client_credentials"
      ],
      code_challenge_methods_supported: ["S256"],
      response_types_supported: ["code", "token"]
    }
  end
end
