defmodule TeiserverWeb.OAuth.CodeController do
  alias Teiserver.Account
  alias Teiserver.OAuth
  alias Teiserver.Steam

  use TeiserverWeb, :controller

  require Logger

  @steam_session_ticket_token_type "urn:tachyon:oauth:token-type:steam_session_ticket"
  @access_token_type "urn:ietf:params:oauth:token-type:access_token"

  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.3
  @spec token(Plug.Conn.t(), %{}) :: Plug.Conn.t()

  def token(conn, %{"grant_type" => "authorization_code"} = params) do
    with :ok <-
           check_required_keys(params, ["code", "redirect_uri", "grant_type"]),
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

  # https://datatracker.ietf.org/doc/html/rfc8693
  # Only Steam session tickets are supported as subject tokens
  def token(conn, %{"grant_type" => "urn:ietf:params:oauth:grant-type:token-exchange"} = params) do
    with :ok <-
           check_required_keys(params, ["subject_token", "subject_token_type"]),
         {:ok, client_id} <- get_client_id(conn, params) do
      steam_token_exchange(conn, client_id, params)
    else
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
           OAuth.exchange_code(code,
             verifier: params["code_verifier"],
             redirect_uri: params["redirect_uri"],
             client_secret: params["client_secret"]
           ) do
      conn |> put_status(200) |> render(:token, token: token)
    else
      {:error, err} ->
        conn
        |> put_status(400)
        |> render(:error, error_description: "invalid request: #{err_message(err)}")
    end
  end

  defp steam_token_exchange(conn, client_id, params) do
    with :ok <- check_steam_exchange_params(params),
         {:ok, app} <- get_app_by_uid(client_id),
         {:ok, scopes} <- check_scopes(app, params),
         {:ok, steam_id} <- Steam.authenticate_ticket(params["subject_token"]),
         :ok <- Steam.check_app_ownership(steam_id),
         {:ok, user} <- Account.get_or_create_steam_user(steam_id, remote_ip(conn)),
         {:ok, token} <- OAuth.create_token(user, app, scopes: scopes) do
      conn
      |> put_status(200)
      |> render(:token,
        token: token,
        issued_token_type: @access_token_type,
        scope: Enum.join(scopes, " ")
      )
    else
      {:error, :unsupported_grant_type} ->
        conn |> put_status(400) |> render(:error, error: "unsupported_grant_type")

      {:error, msg} when is_binary(msg) ->
        conn |> put_status(400) |> render(:error, error_description: msg)

      {:error, :invalid_scope, desc} ->
        conn
        |> put_status(400)
        |> render(:error, error: "invalid_scope", error_description: desc)

      {:error, :invalid_target} ->
        conn
        |> put_status(400)
        |> render(:error,
          error: "invalid_target",
          error_description: "audience and resource are not supported"
        )

      {:error, :invalid_ticket} ->
        conn
        |> put_status(400)
        |> render(:error, error_description: "invalid Steam session ticket")

      {:error, :publisher_banned} ->
        conn |> put_status(400) |> render(:error, error_description: "Steam account banned")

      {:error, :not_owned} ->
        conn
        |> put_status(400)
        |> render(:error, error_description: "Steam account does not own the game")

      {:error, :steam_error} ->
        # Steam unreachable
        conn
        |> put_status(503)
        |> render(:error,
          error: "temporarily_unavailable",
          error_description: "please try again later"
        )

      error ->
        Logger.error("Steam token exchange failed: #{inspect(error)}")

        conn
        |> put_status(500)
        |> render(:error, error: "server_error", error_description: "internal server error")
    end
  end

  defp check_steam_exchange_params(params) do
    cond do
      not Steam.enabled?() ->
        {:error, :unsupported_grant_type}

      params["subject_token_type"] != @steam_session_ticket_token_type ->
        {:error, "unsupported subject_token_type"}

      Map.get(params, "requested_token_type", @access_token_type) != @access_token_type ->
        {:error, "unsupported requested_token_type"}

      Map.has_key?(params, "actor_token") ->
        {:error, "actor_token is not supported"}

      # https://www.rfc-editor.org/rfc/rfc8693.html#section-2.1
      Map.has_key?(params, "actor_token_type") ->
        {:error, "actor_token_type must not be provided without actor_token"}

      Map.has_key?(params, "audience") or Map.has_key?(params, "resource") ->
        {:error, :invalid_target}

      true ->
        :ok
    end
  end

  defp remote_ip(conn) do
    case :inet.ntoa(conn.remote_ip) do
      addr when is_list(addr) -> to_string(addr)
      {:error, :einval} -> nil
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
         {:ok, new_token} <-
           OAuth.refresh_token(token, scopes: scopes, client_secret: params["client_secret"]) do
      conn |> put_status(200) |> render(:token, token: new_token)
    else
      error ->
        Logger.debug("refresh token error #{inspect(error)}")
        conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp get_client_id(conn, params) do
    query = Map.get(params, "client_id")
    basic = OAuth.parse_basic_auth(conn)

    case {basic, query} do
      {:error, nil} ->
        {:error, "missing client_id"}

      {{user, _pass}, client_id} when client_id != nil and user != nil and user != "" ->
        {:error, "cannot provide client_id through both basic auth header and query parameters"}

      {{user, _pass}, nil} ->
        {:ok, user}

      {_basic, client_id} ->
        {:ok, client_id}
    end
  end

  defp get_credentials(conn, params) do
    basic = OAuth.parse_basic_auth(conn)
    post_params = {Map.get(params, "client_id"), Map.get(params, "client_secret")}

    case {basic, post_params} do
      {:error, {nil, nil}} ->
        {:error, "Invalid basic auth header"}

      {{user, _pass}, {client_id, _secret}} when user != nil and client_id != nil ->
        {:error, "Must not provide client_id both in basic auth header and query parameter"}

      {{_user, pass}, {_client_id, secret}} when pass != nil and secret != nil ->
        {:error, "Must not provide client_secret both in basic auth header and query parameter"}

      {{user, pass}, _post_params} ->
        {:ok, user, pass}

      {_basic, {nil, _secret}} ->
        {:error, "missing client_id"}

      {_basic, {_client_id, nil}} ->
        {:error, "missing client_secret"}

      {_basic, {client_id, client_secret}} ->
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

      _other ->
        conn |> put_status(400) |> render(:error, error_description: "invalid request")
    end
  end

  defp check_scopes(app, params) do
    scopes =
      Map.get(params, "scope", "")
      |> String.split()
      |> Enum.map(&String.trim/1)
      |> Enum.into(MapSet.new())

    app_scopes = MapSet.new(app.scopes)

    cond do
      MapSet.size(scopes) == 0 ->
        {:ok, app.scopes}

      MapSet.subset?(scopes, app_scopes) ->
        {:ok, MapSet.to_list(scopes)}

      true ->
        invalid_scopes =
          MapSet.difference(scopes, app_scopes)
          |> MapSet.to_list()
          |> Enum.join(", ")

        {:error, :invalid_scope, "the following scopes aren't allowed: #{invalid_scopes}"}
    end
  end

  def metadata(conn, _params) do
    conn |> put_status(200) |> render(:metadata)
  end

  defp get_app_by_uid(uid) do
    case OAuth.get_application_by_uid(uid) do
      app when not is_nil(app) -> {:ok, app}
      _nil -> {:error, "no application found for uid #{inspect(uid)}"}
    end
  end

  defp err_message(err) do
    # Used to customize the error message to return to the user
    case err do
      :no_code ->
        "no authorization code found"

      :expired ->
        "authorization code has expired"

      _other ->
        try do
          to_string(err)
        rescue
          _exception -> inspect(err)
        end
    end
  end
end
