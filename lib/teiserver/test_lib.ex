defmodule Teiserver.FakeTransport do
  @moduledoc false
  def send(_, _), do: nil
end

defmodule Teiserver.TestLib do
  @moduledoc false
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.Account
  @host '127.0.0.1'

  def raw_setup() do
    {:ok, socket} = :gen_tcp.connect(@host, 8200, active: false)
    %{socket: socket}
  end

  def new_user_name() do
    "new_test_user_#{:random.uniform(99_999_999) + 1_000_000}"
  end

  def new_user(name \\ nil) do
    name = name || new_user_name()

    case User.get_user_by_name(name) do
      nil ->
        {:ok, user} =
          User.user_register_params(name, "#{name}@email.com", "X03MO1qnZdYdgyfeuILPmQ==")
          |> Account.create_user

        user
          |> User.convert_user
          |> User.add_user
      _ ->
        new_user()
    end
  end

  def auth_setup(user \\ nil) do
    user = if user, do: user, else: new_user()

    {:ok, socket} = :gen_tcp.connect(@host, 8200, active: false)
    # Ignore the TASSERVER
    _ = _recv(socket)

    # Now do our login
    _send(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    _ = _recv_until(socket)

    %{socket: socket, user: user}
  end

  def _send(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
  end

  def _recv(socket) do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
    end
  end

  def _recv_until(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} ->
        _recv_until(socket, acc <> to_string(reply))
      {:error, :timeout} ->
        acc
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
      msg_id: nil,
      ip: "127.0.0.1",
      socket: socket,
      transport: socket.transport,
      protocol: protocol
    }
  end

  def mock_state_auth(protocol, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()
    user = new_user()
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
