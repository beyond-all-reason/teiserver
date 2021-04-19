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

  def tls_setup() do
    {:ok, socket} = :ssl.connect(@host, 8201, active: false)
    %{socket: socket}
  end

  def new_user_name() do
    "new_test_user_#{:random.uniform(99_999_999) + 1_000_000}"
  end

  def new_user(name \\ nil, params \\ %{}) do
    name = name || new_user_name()

    case User.get_user_by_name(name) do
      nil ->
        {:ok, user} =
          User.user_register_params(name, "#{name}@email.com", "X03MO1qnZdYdgyfeuILPmQ==", params)
          |> Account.create_user()

        user
        |> User.convert_user()
        |> User.add_user()
        |> User.verify_user()

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

  def _send(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
    :timer.sleep(100)
  end
  def _send(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
  end

  def _recv(socket = {:sslsocket, _, _}) do
    case :ssl.recv(socket, 0, 500) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end
  def _recv(socket) do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
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

  def mock_state_raw(protocol_in, protocol_out, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()

    %{
      # Connection state
      message_part: "",
      last_msg: System.system_time(:second) - 5,
      socket: socket,
      transport: socket.transport,
      protocol_in: protocol_in,
      protocol_out: protocol_out,
      ip: "127.0.0.1",

      # Client state
      userid: nil,
      username: nil,
      battle_host: false,
      user: nil,

      # Connection microstate
      battle_id: nil,
      room_member_cache: %{},
      known_users: %{},
      extra_logging: false
    }
  end

  def mock_state_auth(protocol_in, protocol_out, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()
    user = new_user()
    Client.login(user, self())

    %{
      # Connection state
      message_part: "",
      last_msg: System.system_time(:second) - 5,
      socket: socket,
      transport: socket.transport,
      protocol_in: protocol_in,
      protocol_out: protocol_out,
      ip: "127.0.0.1",

      # Client state
      userid: user.id,
      username: user.name,
      battle_host: false,
      user: user,

      # Connection microstate
      battle_id: nil,
      room_member_cache: %{},
      known_users: %{},
      extra_logging: false
    }
  end

  @spec conn_setup({:ok, List.t()}) :: {:ok, List.t()}
  def conn_setup({:ok, data}) do
    user = data[:user]
    Teiserver.User.recache_user(user.id)

    {:ok, data}
  end

  @spec admin_permissions() :: [String.t()]
  def admin_permissions do
    permissions = ~w(account battle clan party queue tournament)
    |> Enum.map(fn p -> "teiserver.admin.#{p}" end)

    permissions ++ moderator_permissions()
  end

  @spec moderator_permissions() :: [String.t()]
  def moderator_permissions do
    permissions = ~w(account battle clan party queue tournament)
    |> Enum.map(fn p -> "teiserver.moderator.#{p}" end)

    permissions ++ player_permissions()
  end

  @spec player_permissions() :: [String.t()]
  def player_permissions do
    ["teiserver.player.account"]
  end
end
