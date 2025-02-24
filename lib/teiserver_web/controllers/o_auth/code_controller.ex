defmodule TeiserverWeb.OAuth.CodeController do
  use TeiserverWeb, :controller
  alias Teiserver.OAuth

  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.3
  @spec token(Plug.Conn.t(), %{}) :: Plug.Conn.t()

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    with :ok <-
           check_required_keys(params, ["code", "redirect_uri", "code_verifier", "grant_type"]),
         {:ok, client_id} <- get_client_id(conn, params) do
      exchange_token(conn, client_id, params)
    else
      {:error, msg} ->
        conn |> put_status(400) |> render(:error, error_description: msg)
    end
  end

  # As per https://datatracker.ietf.org/doc/html/rfc6749#section-6 this
  # endpoint should accept the parameter `scope`.
  # As of writing, there is only ever one scope allowed: tachyon.lobby
  # so this parameter is ignored.
  # If we ever expand the allowed scopes, this feature should be added
  def token(conn, %{"grant_type" => "refresh_token"} = params) do
    case check_required_keys(params, ["grant_type", "refresh_token", "client_id"]) do
      :ok ->
        refresh_token(conn, params)

      {:error, msg} ->
        conn |> put_status(400) |> render(:error, error_description: msg)
    end
  end

  def token(conn, %{"grant_type" => "client_credentials"} = params) do
    case get_credentials(conn, params) do
      {:ok, client_id, client_secret} ->
        get_token_from_credentials(conn, client_id, client_secret, params)

      {:error, msg} ->
        conn |> put_status(400) |> render(:error, error_description: msg)
    end
  end

  def token(conn, _params) do
    conn
    |> put_status(400)
    |> render(:error, error: "unsupported_grant_type")
  end

  defp check_required_keys(params, keys) do
    case Enum.find(keys, fn key -> not Map.has_key?(params, key) end) do
      nil -> :ok
      missing_key -> {:error, "missing #{missing_key}"}
    end
  end

  defp exchange_token(conn, client_id, params) do
    with {:ok, app} <- get_app_by_uid(client_id),
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
         {:ok, scopes} <- check_scopes(app, params),
         {:ok, token} <- OAuth.get_valid_token(params["refresh_token"]),
         :ok <-
           if(token.application_id == app.id,
             do: :ok,
             else: {:error, "token doesn't match application. Invalid token for this client_id"}
           ),
         {:ok, new_token} <- OAuth.refresh_token(token, scopes: scopes) do
      conn |> put_status(200) |> render(:token, token: new_token)
    else
      _ -> conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp get_client_id(conn, params) do
    query = Map.get(params, "client_id")
    basic = OAuth.parse_basic_auth(conn)

    case {basic, query} do
      {:error, nil} ->
        {:error, "missing client_id"}

      {{user, _}, client_id} when client_id != nil and user != nil and user != "" ->
        {:error, "cannot provide client_id through both basic auth header and query parameters"}

      {{user, _}, nil} ->
        {:ok, user}

      {_, client_id} ->
        {:ok, client_id}
    end
  end

  defp get_credentials(conn, params) do
    basic = OAuth.parse_basic_auth(conn)
    post_params = {Map.get(params, "client_id"), Map.get(params, "client_secret")}

    case {basic, post_params} do
      {:error, {nil, nil}} ->
        {:error, "Invalid basic auth header"}

      {{user, _}, {client_id, _}} when user != nil and client_id != nil ->
        {:error, "Must not provide client_id both in basic auth header and query parameter"}

      {{_, pass}, {_, secret}} when pass != nil and secret != nil ->
        {:error, "Must not provide client_secret both in basic auth header and query parameter"}

      {{user, pass}, _} ->
        {:ok, user, pass}

      {_, {nil, _}} ->
        {:error, "missing client_id"}

      {_, {_, nil}} ->
        {:error, "missing client_secret"}

      {_, {client_id, client_secret}} ->
        {:ok, client_id, client_secret}
    end
  end

  defp get_token_from_credentials(conn, client_id, client_secret, scopes) do
    with {:ok, cred} <- OAuth.get_valid_credentials(client_id, client_secret),
         {:ok, scopes} <- check_scopes(cred.application, scopes),
         {:ok, token} <- OAuth.get_token_from_credentials(cred, scopes) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      # https://www.rfc-editor.org/rfc/rfc6749#section-5.2 server may return 401
      {:error, :invalid_password} ->
        conn
        |> put_status(401)
        |> render(:error, error: "invalid_client", error_description: "invalid credentials")

      {:error, :invalid_scope, desc} ->
        conn
        |> put_status(400)
        |> render(:error, error: "invalid_scope", error_description: desc)

      _ ->
        conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp check_scopes(app, params) do
    scopes =
      Map.get(params, "scope", "")
      |> String.split()
      |> Enum.map(&String.split/1)
      |> Enum.into(MapSet.new())

    app_scopes = MapSet.new(app.scopes)

    cond do
      MapSet.size(scopes) == 0 ->
        {:ok, app.scopes}

      MapSet.subset?(scopes, app_scopes) ->
        {:ok, MapSet.to_list(scopes)}

      true ->
        invalid_scopes = MapSet.difference(scopes, app_scopes)

        {:error, :invalid_scope,
         "the following scopes aren't allowed: #{inspect(MapSet.to_list(invalid_scopes))}"}
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
