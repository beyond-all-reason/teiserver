defmodule Teiserver.Protocols.Tachyon.V1.ClientOut do
  @spec do_reply(atom(), any) :: Map.t()
  def do_reply(:client_list, clients) do
    %{
      cmd: "s.client.client_list",
      clients: clients
    }
  end
end
