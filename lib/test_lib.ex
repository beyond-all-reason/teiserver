defmodule Teiserver.TestLib do
  @host '127.0.0.1'

  def raw_setup() do
    {:ok, socket} = :gen_tcp.connect(@host, 8200, [active: false])
    %{socket: socket}
  end

  def auth_setup(username \\ "TestUser") do
    {:ok, socket} = :gen_tcp.connect(@host, 8200, [active: false])
    # Ignore the TASSERVER
    _ = _recv(socket)
    
    # Now do our login
    _send(socket, "LOGIN #{username} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n")
    _ = _recv(socket)

    %{socket: socket}
  end

  def _send(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
  end

  def _recv(socket) do
    {:ok, reply} = :gen_tcp.recv(socket, 0, 1000)
    reply |> to_string
  end
end