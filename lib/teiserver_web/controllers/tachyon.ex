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

  plug Teiserver.OAuth.TokenPlug

  def connect(conn, _opts) do
    conn
    |> WebSockAdapter.upgrade(Teiserver.Tachyon.Transport, %{}, timeout: 20_000)
    |> halt()
  end
end
