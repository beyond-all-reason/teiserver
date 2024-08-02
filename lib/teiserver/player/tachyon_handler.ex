defmodule Teiserver.Player.TachyonHandler do
  @moduledoc """
  Player specific code to handle tachyon logins and actions
  """

  alias Teiserver.Tachyon.Handler
  alias Teiserver.Data.Types, as: T

  @behaviour Handler

  @type state :: %{user: T.user()}

  @impl Handler
  def connect(_conn) do
    {:ok, nil}
  end

  @impl Handler
  @spec init(state()) :: WebSock.handle_result()
  def init(state) do
    # this is inside the process that maintain the connection
    {:ok, state}
  end
end
