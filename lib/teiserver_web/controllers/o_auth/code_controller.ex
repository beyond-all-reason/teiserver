defmodule TeiserverWeb.OAuth.CodeController do
  use TeiserverWeb, :controller
  alias Teiserver.OAuth

  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.3
  @spec token(Plug.Conn.t(), %{}) :: Plug.Conn.t()

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
    case get_credentials(conn, params) do
      {:ok, client_id, client_secret} ->
        get_token_from_credentials(conn, client_id, client_secret)

      {:error, msg} ->
        conn |> put_status(400) |> render(:error, error_description: msg)
    end
  end

  def token(conn, _params) do
    conn |> put_status(400) |> render(:error, error_description: "invalid grant_type")
  end

  defp exchange_token(conn, params) do
    with {:ok, app} <- get_app_by_uid(params["client_id"]),
         {:ok, code} <- OAuth.get_valid_code(params["code"]),
         :ok <-
           if(code.application_id == app.id,
             do: :ok,
             else: {:error, "code doesn't match application. Invalid code for this client_id"}
           ),
         {:ok, token} <-
           OAuth.exchange_code(code, params["code_verifier"], params["redirect_uri"]) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      {:error, err} ->
        conn
        |> put_status(400)
        |> render(:error, error_description: "invalid request: #{err_message(err)}")
    end
  end

  defp refresh_token(conn, params) do
    with {:ok, app} <- get_app_by_uid(params["client_id"]),
         {:ok, token} <- OAuth.get_valid_token(params["refresh_token"]),
         :ok <-
           if(token.application_id == app.id,
             do: :ok,
             else: {:error, "token doesn't match application. Invalid token for this client_id"}
           ),
         {:ok, new_token} <- OAuth.refresh_token(token) do
      conn |> put_status(200) |> render(:token, token: new_token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp get_credentials(conn, params) do
    basic = Plug.BasicAuth.parse_basic_auth(conn)
    post_params = {Map.get(params, "client_id"), Map.get(params, "client_secret")}

    case {basic, post_params} do
      {:error, {nil, nil}} -> {:error, "unauthorized"}
      {{user, pass}, _} -> {:ok, user, pass}
      {_, {nil, _}} -> {:error, "missing client_id"}
      {_, {_, nil}} -> {:error, "missing client_secret"}
      {_, {client_id, client_secret}} -> {:ok, client_id, client_secret}
    end
  end

  defp get_token_from_credentials(conn, client_id, client_secret) do
    with {:ok, cred} <- OAuth.get_valid_credentials(client_id, client_secret),
         {:ok, token} <- OAuth.get_token_from_credentials(cred) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  def metadata(conn, _params) do
    conn |> put_status(200) |> render(:metadata)
  end

  defp get_app_by_uid(uid) do
    case OAuth.get_application_by_uid(uid) do
      app when not is_nil(app) -> {:ok, app}
      _ -> {:error, "no application found for uid #{inspect(uid)}"}
    end
  end

  defp err_message(err) do
    # Used to customize the error message to return to the user
    case err do
      :no_code ->
        "no authorization code found"

      :expired ->
        "authorization code has expired"

      _ ->
        try do
          to_string(err)
        rescue
          _ -> inspect(err)
        end
    end
  end
end
