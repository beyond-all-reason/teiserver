defmodule Teiserver.TcpServerTest do
  use ExUnit.Case

  @host '127.0.0.1'
  
  setup do
    {:ok, socket} = :gen_tcp.connect(@host, 8200, [active: false])
    {:ok, socket: socket}
  end
  
  defp _send(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
  end

  defp _recv(socket) do
    {:ok, reply} = :gen_tcp.recv(socket, 0, 1000)
    reply |> to_string
  end

  test "test startup", %{socket: socket} do
    # We expect to be greeted by a welcome message
    reply = _recv(socket)
    assert reply == "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"

    _send(socket, "LOGIN Addas password 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
    reply = _recv(socket)
    [accepted | _remainder] = String.split(reply, "\n")
    assert accepted == "ACCEPTED Addas"
  end
end