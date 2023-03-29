defmodule Teiserver.Protocols.Tachyon.V1.ClientIn do
  alias Teiserver.{Client}
  alias Teiserver.Protocols.Tachyon.V1.Tachyon
  import Teiserver.Protocols.Tachyon.V1.TachyonOut, only: [reply: 4]
  alias Teiserver.Data.Types, as: T

  @spec do_handle(String.t(), Map.t(), T.tachyon_tcp_state()) :: T.tachyon_tcp_state()
  def do_handle("list_clients_from_ids", %{"id_list" => id_list}, state) do
    clients =
      Client.get_clients(id_list)
      |> Enum.filter(fn c -> c != nil end)
      |> Enum.map(fn c -> Tachyon.convert_object(c, :client) end)

    reply(:client, :client_list, clients, state)
  end

  def do_handle(cmd, data, state) do
    reply(
      :system,
      :error,
      %{
        location: "auth.handle",
        error: "No match for cmd: '#{cmd}' with data '#{Kernel.inspect(data)}'"
      },
      state
    )
  end
end
