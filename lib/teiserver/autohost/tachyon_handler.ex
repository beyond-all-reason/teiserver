defmodule Teiserver.Autohost.TachyonHandler do
  @moduledoc """
  Handle a connection with an autohost using the tachyon protocol.

  This is treated separately from a player connection because they fulfill
  very different roles, have very different behaviour and states.
  """
  alias Teiserver.Tachyon.Handler
  alias Teiserver.Autohost.Autohost
  @behaviour Handler

  @type state :: %{autohost: Autohost.t()}

  @impl Handler
  def connect(conn) do
    autohost = conn.assigns[:token].autohost
    {:ok, %{autohost: autohost}}
  end

  @impl Handler
  @spec init(state()) :: WebSock.handle_result()
  def init(state) do
    {:ok, _} = Teiserver.Autohost.Registry.register(state.autohost.id)
    {:ok, state}
  end

  @impl Handler
  def handle_info(_msg, state) do
    {:ok, state}
  end
end
