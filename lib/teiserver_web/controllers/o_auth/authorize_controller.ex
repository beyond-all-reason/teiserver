defmodule TeiserverWeb.OAuth.AuthorizeController do
  alias Ecto.Changeset
  alias Teiserver.OAuth

  use TeiserverWeb, :controller

  def authorize(conn, params) when not is_map_key(params, "client_id") do
    bad_request(conn, "missing client_id")
  end

  def authorize(conn, %{"client_id" => client_id} = params) do
    with app when app != nil <- OAuth.get_application_by_uid(client_id),
         true <- OAuth.can_create_code?(app),
         {:ok, _parsed_scopes} <- check_requested_scopes(app.scopes, params["scope"]),
         {:ok, redir_uri} <- OAuth.get_redirect_uri(app, Map.get(conn.params, "redirect_uri")) do
      authorized_apps = OAuth.list_authorized_applications(conn.assigns.current_user.id)

      if Enum.find(authorized_apps, &(&1.id == app.id)) != nil do
        params = Map.put(params, "response_type", "code")
        do_generate_code(conn, app, redir_uri, params)
      else
        reject_uri =
          error_redirect_uri(
            conn,
            redir_uri,
            "access_denied",
            "user refused to authorize application"
          )

        permissions = Enum.map(app.scopes, &OAuth.scope_description/1)

        conn
        |> render("authorize.html",
          app_name: app.name,
          permissions: permissions,
          params: params,
          reject_uri: reject_uri
        )
      end
    else
      nil ->
        bad_request(conn, "invalid client_id")

      false ->
        conn
        |> render("bad_request.html",
          reason: "Cannot use this application to create auth token"
        )

      {:error, {:invalid_scopes, scopes}} ->
        scopes = Enum.join(scopes, ", ")
        bad_request(conn, "Cannot request the following scopes: #{scopes}")

      {:error, err} ->
        bad_request(conn, "invalid redirection uri: #{inspect(err)}")
    end
  end

  def authorize(conn, _params) do
    conn |> render("bad_request.html")
  end

  def generate_code(conn, params) when not is_map_key(params, "client_id") do
    bad_request(conn, "missing client_id")
  end

  def generate_code(conn, params) when not is_map_key(params, "redirect_uri") do
    bad_request(conn, "missing redirect_uri")
  end

  def generate_code(conn, %{"client_id" => client_id, "redirect_uri" => redirect_uri} = params) do
    with app when app != nil <- OAuth.get_application_by_uid(client_id),
         {:ok, redir_url} <- OAuth.get_redirect_uri(app, redirect_uri) do
      do_generate_code(conn, app, redir_url, params)
    else
      nil ->
        bad_request(conn, "invalid client_id")

      {:error, _reason} ->
        bad_request(conn, "invalid redirection url")
    end
  end

  defp do_generate_code(conn, app, redir_url, params) do
    checked_scopes = check_requested_scopes(app.scopes, params["scope"])

    cond do
      Map.get(params, "response_type") != "code" ->
        error_redirect(conn, redir_url, "unsupported_response_type", "only code is supported")

      Map.get(params, "code_challenge") == nil ->
        error_redirect(conn, redir_url, "invalid_request", "a code challenge must be provided")

      elem(checked_scopes, 0) == :error ->
        {:error, {:invalid_scopes, scopes}} = checked_scopes
        scopes = Enum.join(scopes, ", ")

        error_redirect(
          conn,
          redir_url,
          "invalid_request",
          "cannot request the following scopes #{scopes}"
        )

      true ->
        {:ok, scopes} = checked_scopes

        code_params = %{
          application: app,
          redirect_uri: URI.to_string(redir_url),
          scopes: scopes,
          challenge: Map.get(params, "code_challenge"),
          challenge_method: Map.get(params, "code_challenge_method")
        }

        case OAuth.create_code(conn.assigns.current_user, code_params) do
          {:error, %Changeset{} = err} ->
            errors =
              Changeset.traverse_errors(err, fn {msg, _opts} -> msg end)
              |> Enum.map(fn {k, msgs} ->
                errs = Enum.join(msgs, ", ")
                "#{k}: #{errs}"
              end)

            reason = Enum.join(errors, " - ")
            bad_request(conn, reason)

          {:error, _reason} ->
            error_redirect(conn, redir_url, "server_error", "something went wrong")

          {:ok, code} ->
            query =
              URI.decode_query(redir_url.query || "")
              |> Map.put(:code, code.value)
              |> then(fn query ->
                # only include state if it was provided in the first place
                case Map.get(params, "state", "") do
                  "" -> query
                  st -> Map.put(query, "state", st)
                end
              end)
              |> Map.put(:scope, Enum.join(code.scopes, " "))
              |> URI.encode_query()

            conn |> redirect(external: URI.to_string(%{redir_url | query: query}))
        end
    end
  end

  # If the server can validate the client id and the redirection url
  # it should use the redirect url with an added query string to indicate failure
  # otherwise notify the user of the error. See
  # https://www.rfc-editor.org/rfc/rfc6749.html#section-4.1.2.1
  defp bad_request(conn, reason) do
    conn
    |> put_status(400)
    |> render("bad_request.html", reason: reason)
  end

  defp check_requested_scopes(app_scopes, nil), do: {:ok, app_scopes}

  defp check_requested_scopes(app_scopes, requested_scope_string) do
    scopes = String.split(requested_scope_string)

    invalid_scopes =
      scopes
      |> MapSet.new()
      |> MapSet.difference(MapSet.new(app_scopes))

    if MapSet.size(invalid_scopes) == 0,
      do: {:ok, scopes},
      else: {:error, {:invalid_scopes, invalid_scopes}}
  end

  defp error_redirect_uri(conn, %URI{} = redir_url, error, description) do
    final_query =
      URI.decode_query(redir_url.query || "")
      |> Map.put(:error, error)
      |> Map.put(:error_description, description)
      |> then(fn q ->
        case Map.get(conn.params, "state") do
          nil -> q
          st -> Map.put(q, :state, st)
        end
      end)
      |> URI.encode_query()

    URI.to_string(%{redir_url | query: final_query})
  end

  defp error_redirect(conn, redir_url, error, description) do
    uri = error_redirect_uri(conn, redir_url, error, description)

    conn |> redirect(external: uri)
  end
end
