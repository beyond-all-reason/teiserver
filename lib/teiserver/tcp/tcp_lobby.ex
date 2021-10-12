defmodule Teiserver.Tcp.TcpLobby do
  def handle_info({:client_message, :lobby, _userid, _data}, state) do
    state
  end
end
