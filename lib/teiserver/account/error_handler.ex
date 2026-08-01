defmodule Teiserver.Account.ErrorHandler do
  @moduledoc false

  alias Phoenix.Controller

  use TeiserverWeb, :html

  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler
  @impl Guardian.Plug.ErrorHandler

  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
    if json_request?(conn) do
      unauthorized_json(conn, "unauthenticated")
    else
      redirect_to =
        if conn.query_string != nil && conn.query_string != "" do
          "#{conn.request_path}?#{conn.query_string}"
        else
          "#{conn.request_path}"
        end

      conn
      |> put_resp_cookie("_redirect_to", redirect_to, sign: true, max_age: 60 * 5)
      |> Controller.redirect(to: ~p"/login")
    end
  end

  def auth_error(conn, {:invalid_token, _message}, _opts) do
    if json_request?(conn) do
      unauthorized_json(conn, "invalid_token")
    else
      conn
      |> put_resp_cookie("_teiserver_key", "", max_age: 0)
      |> Controller.redirect(to: ~p"/login")
    end
  end

  def auth_error(conn, {type, _reason}, _opts) do
    if json_request?(conn) do
      unauthorized_json(conn, to_string(type))
    else
      body = to_string(type)

      conn
      |> put_resp_content_type("text/plain")
      |> send_resp(401, body)
    end
  end

  # :accepts sets phoenix_format, so every json pipeline is covered without
  # hardcoding route prefixes here.
  defp json_request?(conn), do: conn.private[:phoenix_format] == "json"

  defp unauthorized_json(conn, reason) do
    conn
    |> put_status(:unauthorized)
    |> Controller.json(%{error: reason})
    |> halt()
  end
end
