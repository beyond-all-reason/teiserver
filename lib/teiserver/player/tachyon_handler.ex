defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T

  @behaviour Handler

  @type state :: %{user: T.user()}

  @impl Handler
  def connect(conn) do
    # TODO: get the IP from request (somehow)
    ip = "127.0.0.1"
    lobby_client = conn.assigns[:token].application.uid
    user = conn.assigns[:token].owner

    case Teiserver.CacheUser.tachyon_login(user, ip, lobby_client) do
      {:ok, user} ->
        {:ok, %{user: user}}

      {:error, :rate_limited, msg} ->
        {:error, 429, msg}

      {:error, msg} ->
        {:error, 403, msg}
    end
  end

  @impl Handler
  @spec init(state()) :: WebSock.handle_result()
  def init(state) do
    # this is inside the process that maintain the connection
    # TODO: register may return an error when the same user is already connected
    # elsewhere. Handle that soon
    {:ok, _} = Teiserver.Player.Registry.register(state.user.id)
    {:ok, state}
  end
end
