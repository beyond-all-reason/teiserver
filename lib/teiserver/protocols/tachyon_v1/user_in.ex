defmodule Teiserver.Protocols.Tachyon.V1.UserIn do
  # alias Teiserver.{User, Client}
  # alias Teiserver.Protocols.Tachyon.V1.Tachyon
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]

  @spec do_handle(String.t(), Map.t(), Map.t()) :: Map.t()
  def do_handle("query", %{"query" => _query}, state) do
    state
  end

  def do_handle(cmd, data, state) do
    reply(:system, :error, %{location: "auth.handle", error: "No match for cmd: '#{cmd}' with data '#{data}'"}, state)
  end
end
