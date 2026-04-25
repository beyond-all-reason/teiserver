defmodule Teiserver.Account.ErrorHandler do
  @moduledoc false

  alias Phoenix.Controller

  use TeiserverWeb, :html

  import Plug.Conn

  @behaviour Guardian.Plug.ErrorHandler
  @impl Guardian.Plug.ErrorHandler

  def auth_error(conn, {:unauthenticated, _reason}, _opts) do
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

  def auth_error(conn, {:invalid_token, _message}, _opts) do
    conn
    |> put_resp_cookie("_teiserver_key", "", max_age: 0)
    |> Controller.redirect(to: ~p"/login")
  end

  def auth_error(conn, {type, _reason}, _opts) do
    body = to_string(type)

    conn
    |> put_resp_content_type("text/plain")
    |> send_resp(401, body)
  end
end
