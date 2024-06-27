defmodule TeiserverWeb.OAuth.AuthorizeController do
  use TeiserverWeb, :controller

  alias Teiserver.OAuth

  def authorize(conn, params) when not is_map_key(params, "client_id") do
    bad_request(conn, "missing client_id")
  end

  def authorize(conn, %{"client_id" => client_id} = params) do
    case OAuth.get_application_by_uid(client_id) do
      nil ->
        bad_request(conn, "invalid client_id")

      app ->
        conn
        |> render("authorize.html",
          app_name: app.name,
          params: params
        )
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
    case OAuth.get_application_by_uid(client_id) do
      nil ->
        bad_request(conn, "invalid client_id")

      app ->
        case OAuth.get_redirect_uri(app, redirect_uri) do
          {:error, _} -> bad_request(conn, "invalid redirection url")
          {:ok, redir_url} -> do_generate_code(conn, app, redir_url, params)
        end
    end
  end

  defp do_generate_code(conn, app, redir_url, params) do
    cond do
      Map.get(params, "response_type") != "code" ->
        error_redirect(conn, redir_url, "unsupported_response_type", "only code is supported")

      Map.get(params, "code_challenge_method") != "S256" ->
        error_redirect(conn, redir_url, "invalid_request", "only S256 is supported")

      Map.get(params, "code_challenge") == nil ->
        error_redirect(conn, redir_url, "invalid_request", "a code challenge must be provided")

      true ->
        code_params = %{
          id: app.id,
          redirect_uri: URI.to_string(redir_url),
          scopes: app.scopes,
          challenge: Map.get(params, "code_challenge"),
          challenge_method: "S256"
        }

        case OAuth.create_code(conn.assigns.current_user, code_params) do
          {:error, _} ->
            error_redirect(conn, redir_url, "server_error", "something went wrong")

          {:ok, code} ->
            query =
              URI.decode_query(redir_url.query || "")
              |> Map.put(:code, code.value)
              |> Map.merge(Map.take(params, ["state"]))
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

  defp error_redirect(conn, %URI{} = redir_url, error, description) do
    final_query =
      URI.decode_query(redir_url.query || "")
      |> Map.put(:error, error)
      |> Map.put(:error_description, description)
      |> URI.encode_query()

    conn |> redirect(external: URI.to_string(%{redir_url | query: final_query}))
  end
end
