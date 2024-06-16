defmodule TeiserverWeb.OAuth.CodeController do
  use TeiserverWeb, :controller
  alias Teiserver.OAuth

  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.3
  @spec token(Conn.t(), %{}) :: Conn.t()

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    case Enum.find(
           ["client_id", "code", "redirect_uri", "client_id", "code_verifier", "grant_type"],
           fn key -> not Map.has_key?(params, key) end
         ) do
      nil ->
        exchange_token(conn, params)

      missing_key ->
        conn |> put_status(400) |> render(:error, error_description: "missing #{missing_key}")
    end
  end

  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    case Enum.find(
           ["grant_type", "refresh_token", "client_id"],
           fn key -> not Map.has_key?(params, key) end
         ) do
      nil ->
        refresh_token(conn, params)

      missing_key ->
        conn |> put_status(400) |> render(:error, error_description: "missing #{missing_key}")
    end
  end

  def token(conn, %{"grant_type" => "client_credentials"} = params) do
    case Enum.find(
           ["grant_type", "client_id", "client_secret"],
           fn key -> not Map.has_key?(params, key) end
         ) do
      nil ->
        get_token_from_credentials(conn, params)

      missing_key ->
        conn |> put_status(400) |> render(:error, error_description: "missing #{missing_key}")
    end
  end

  def token(conn, _params) do
    conn |> put_status(400) |> render(:error, error_description: "invalid grant_type")
  end

  defp exchange_token(conn, params) do
    with app when app != nil <- OAuth.get_application_by_uid(params["client_id"]),
         {:ok, code} <- OAuth.get_valid_code(params["code"]),
         true <- code.application_id == app.id,
         {:ok, token} <-
           OAuth.exchange_code(code, params["code_verifier"], params["redirect_uri"]) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp refresh_token(conn, params) do
    with app when app != nil <- OAuth.get_application_by_uid(params["client_id"]),
         {:ok, token} <- OAuth.get_valid_token(params["refresh_token"]),
         true <- token.application_id == app.id,
         {:ok, new_token} <- OAuth.refresh_token(token) do
      conn |> put_status(200) |> render(:token, token: new_token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp get_token_from_credentials(conn, params) do
    with {:ok, cred} <- OAuth.get_valid_credentials(params["client_id"], params["client_secret"]),
         {:ok, token} <- OAuth.get_token_from_credentials(cred) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end
end
