defmodule Teiserver.Tachyon.MessageHandlers.LobbyHostMessageHandlers do
  @moduledoc """

  """
  alias Teiserver.Data.Types, as: T

  @spec handle(map(), T.tachyon_ws_state()) :: {:ok, T.tachyon_ws_state()} | {:ok, map() | list(), T.tachyon_ws_state()}
  def handle(%{} = msg, state) do
    IO.puts __MODULE__
    IO.inspect msg
    IO.puts ""

    {:ok, state}
  end
end
