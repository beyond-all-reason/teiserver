defmodule Teiserver.FakeTransport do
  def send(_, _), do: nil
end

defmodule Teiserver.TestLib do
  alias Teiserver.User
  alias Teiserver.Client
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
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
    end
  end

  def mock_socket() do
    %{
      transport: Teiserver.FakeTransport
    }
  end

  def mock_state_raw(protocol, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()

    %{
      userid: nil,
      name: nil,
      client: nil,
      user: nil,
      socket: socket,
      msg_id: nil,
      transport: socket.transport,
      protocol: protocol
    }
  end

  def mock_state_auth(protocol, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()
    user = User.get_user_by_name("TestUser")
    client = Client.login(user, self(), protocol)

    %{
      userid: user.id,
      name: user.name,
      client: client,
      user: user,
      socket: socket,
      msg_id: nil,
      transport: socket.transport,
      protocol: protocol
    }
  end
end
