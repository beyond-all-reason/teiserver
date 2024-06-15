defmodule TeiserverWeb.OAuth.CodeView do
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
end
