defmodule TeiserverWeb.TachyonController do
  @moduledoc """
  This is merely used to upgrade the connection to websocket.
  We don't use Phoenix.Endpoint.socket/3 because they don't expose the
  handshake process. This limits us in two ways:
  * check the OAuth token and scopes
  * verify the websocket subprotocol. The default socket can only handle
    a fixed list of subprotocol which isn't fit for our purpose.
  """
  use TeiserverWeb, :controller

  plug Teiserver.OAuth.Plug.EnsureAuthenticated

  @subprotocol_hdr_name "sec-websocket-protocol"

  def connect(conn, _opts) do
    with {:ok, subprotocol, handler} <- handler_for_version(conn),
         {:ok, state} <- handler.connect(conn) do
      try do
        conn_state = %{handler_state: state, handler: handler}

        conn
        |> put_resp_header(@subprotocol_hdr_name, subprotocol)
        |> WebSockAdapter.upgrade(Teiserver.Tachyon.Transport, conn_state, timeout: 20_000)
        |> halt()
      rescue
        e in WebSockAdapter.UpgradeError -> error_resp(conn, 500, e.message)
      end
    else
      :error -> error_resp(conn, 500, "Unknown error")
      {:error, code, msg} -> error_resp(conn, code, msg)
    end
  end

  defp handler_for_version(conn) do
    subprotocol_headers =
      get_req_header(conn, @subprotocol_hdr_name)
      |> Enum.flat_map(&String.split(&1, ","))
      |> Enum.map(&String.trim/1)

    supported_version = "v0.tachyon"

    cond do
      subprotocol_headers == [] ->
        {:error, 400, "must provide header #{@subprotocol_hdr_name}"}

      Enum.member?(subprotocol_headers, supported_version) ->
        token = conn.assigns[:token]

        cond do
          not is_nil(token.owner_id) ->
            {:ok, supported_version, Teiserver.Player.TachyonHandler}

          not is_nil(token.bot_id) ->
            {:ok, supported_version, Teiserver.Autohost.TachyonHandler}

          true ->
            {:error, 500, "no owner nor autohost found for token, this should never happen"}
        end

      true ->
        {:error, 400, "No supported subprotocol version found in #{inspect(subprotocol_headers)}"}
    end
  end

  # there must be a better way to reply with json, but this'll be enough
  # for this controller
  defp error_resp(conn, code, message) do
    err =
      case code do
        400 -> "invalid_request"
        403 -> "unauthorized_client"
        429 -> "rate_limited"
        500 -> "server_error"
      end

    conn
    |> put_resp_header("content-type", "application/json")
    |> send_resp(code, Jason.encode!(%{error: err, error_description: message}))
  end
end
