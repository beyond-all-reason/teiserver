defmodule Teiserver.Protocols.Tachyon.V1.SystemIn do
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("ping", cmd, state) do
    reply(:system, :pong, cmd, state)
  end
end
