defmodule Teiserver.Account.ApiAuthPlug do
  @moduledoc """
  Authenticates a json api request from an `Authorization: Bearer <token>`
  header and assigns `:current_user`.

  The credential is a guardian access token, the same one the browser session
  is built on, but the api takes it from the header and never from a session or
  a cookie. This is the api counterpart of `Teiserver.Account.AuthPlug`; the two
  are kept apart so that neither has to ask what kind of request it is looking
  at, and so that a failure here answers with json rather than a redirect to the
  login page.

  Users restricted from logging in, or flagged as a smurf, are rejected however
  they authenticated - without that a banned user would keep a working
  credential on the api.
  """

  alias Phoenix.Controller
  alias Teiserver.Account
  alias Teiserver.Account.AuthLib
  alias Teiserver.Account.Guardian

  import Plug.Conn

  require Logger

  @behaviour Plug

  def init(opts), do: opts

  def call(conn, _opts) do
    with {:ok, raw_token} <- bearer_token(conn),
         {:ok, user} <- user_from_token(raw_token),
         :ok <- login_allowed(user) do
      Logger.metadata([user_id: user.id] ++ Logger.metadata())

      assign(conn, :current_user, user)
    else
      {:error, :restricted} -> error_response(conn, :forbidden, "account_restricted")
      {:error, reason} -> error_response(conn, :unauthorized, reason)
    end
  end

  defp bearer_token(conn) do
    case get_req_header(conn, "authorization") do
      ["Bearer " <> raw_token] ->
        case String.trim(raw_token) do
          "" -> {:error, "invalid_token"}
          token -> {:ok, token}
        end

      _other ->
        {:error, "unauthenticated"}
    end
  end

  # Constrained to access tokens to match Teiserver.Account.AuthPipeline, so a
  # refresh token can't be swapped in here
  defp user_from_token(raw_token) do
    case Guardian.resource_from_token(raw_token, %{"typ" => "access"}) do
      {:ok, %Account.User{} = user, _claims} -> {:ok, user}
      _error -> {:error, "invalid_token"}
    end
  end

  defp login_allowed(user) do
    if AuthLib.blocked_from_login?(user) do
      {:error, :restricted}
    else
      :ok
    end
  end

  defp error_response(conn, status, reason) do
    conn
    |> put_status(status)
    |> Controller.json(%{error: reason})
    |> halt()
  end
end
