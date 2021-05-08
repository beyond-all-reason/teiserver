defmodule Teiserver.Protocols.Tachyon.SystemIn do
  import Teiserver.Protocols.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("ping", cmd, state) do
    reply(:system, :pong, cmd, state)
  end
end
