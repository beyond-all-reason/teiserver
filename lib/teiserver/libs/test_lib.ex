defmodule Teiserver.FakeTransport do
  @moduledoc false
  def send(_transport, _msg), do: nil
end

defmodule Teiserver.TeiserverTestLib do
  @moduledoc false
  alias Teiserver.{Client, User, Account, SpringIdServer}
  alias Teiserver.Account.AccoladeLib
  alias Teiserver.Protocols.TachyonLib
  alias Teiserver.Coordinator.CoordinatorServer
  @host '127.0.0.1'

  @spec raw_setup :: %{socket: port()}
  def raw_setup() do
    {:ok, socket} = :gen_tcp.connect(@host, 9200, active: false)
    %{socket: socket}
  end

  # Looks like we might want to use https://erlang.org/documentation/doc-12.0/lib/ssl-10.4/doc/html/ssl.html#connect-2
  # and upgrade the connection instead?
  @spec spring_tls_setup :: %{socket: port()}
  def spring_tls_setup() do
    {:ok, socket} =
      :ssl.connect(@host, 9201,
        active: false,
        verify: :verify_none
      )

    %{socket: socket}
  end

  @spec tachyon_tls_setup :: %{socket: port()}
  def tachyon_tls_setup() do
    {:ok, socket} =
      :ssl.connect(@host, 9202,
        active: false,
        verify: :verify_none
      )

    %{socket: socket}
  end

  @spec new_user_name :: String.t()
  def new_user_name() do
    "test_user_#{:rand.uniform(99_999_999) + 1_000_000}"
  end

  @spec new_user(any, any) :: atom | %{:id => any, optional(any) => any}
  def new_user(name \\ nil, params \\ %{}) do
    name = name || new_user_name()

    case User.get_user_by_name(name) do
      nil ->
        {:ok, user} =
          User.user_register_params_with_md5(
            name,
            "#{name}@email.com",
            "X03MO1qnZdYdgyfeuILPmQ==",
            Map.merge(%{admin_group_id: Teiserver.user_group_id()}, params)
          )
          |> Account.create_user()

        Account.create_group_membership(%{
          user_id: user.id,
          group_id: Teiserver.user_group_id()
        })

        Account.update_user_stat(user.id, %{
          "country" => "??",
          "lobby_client" => "LuaLobby Chobby"
        })

        user
        |> User.convert_user()
        |> Map.put(:springid, SpringIdServer.get_next_id())
        |> User.add_user()
        |> User.verify_user()

      _ ->
        new_user()
    end
  end

  @spec async_auth_setup(module(), nil | Map.t()) :: %{user: Map.t(), state: Map.t()}
  def async_auth_setup(protocol, user \\ nil) do
    user = if user, do: user, else: new_user()

    token = User.create_token(user)

    case User.try_login(token, "127.0.0.1", "AsyncTest", "token1 token2") do
      {:ok, _user} -> :ok
      value -> raise "Error setting up user - #{Kernel.inspect(value)}"
    end

    Client.login(user, :test, "127.0.0.1")

    state = mock_async_state(protocol.protocol_in(), protocol.protocol_out(), user)
    %{user: user, state: state}
  end

  @spec auth_setup(nil | Map.t()) :: %{socket: port(), user: Map.t(), pid: pid()}
  def auth_setup(user \\ nil) do
    user = if user, do: user, else: new_user()

    %{socket: socket} = raw_setup()
    # Ignore the TASSERVER
    _ = _recv_raw(socket)

    # Now do our login
    _send_raw(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506 0d04a635e200f308\tb sp\n"
    )

    _ = _recv_until(socket)

    pid =
      case Client.get_client_by_id(user.id) do
        nil ->
          :timer.sleep(250)
          Client.get_client_by_id(user.id)

        client ->
          client.tcp_pid
      end

    %{socket: socket, user: user, pid: pid}
  end

  @spec tachyon_auth_setup(nil | Map.t()) :: %{socket: port(), user: Map.t(), pid: pid()}
  def tachyon_auth_setup(user \\ nil) do
    user = if user, do: user, else: new_user()
    token = User.create_token(user)

    %{socket: socket} = tachyon_tls_setup()

    # Now do our login
    data = %{
      cmd: "c.auth.login",
      token: token,
      lobby_name: "ex_test",
      lobby_version: "1a",
      lobby_hash: "t1 t2"
    }

    _tachyon_send(socket, data)
    _tachyon_recv(socket)

    pid = Client.get_client_by_id(user.id).tcp_pid
    %{socket: socket, user: user, pid: pid}
  end

  def _send_lines(state = %{mock: true}, msg) do
    state.protocol_in.data_in(msg, state)
  end

  def _send_raw(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
    :timer.sleep(100)
  end

  def _send_raw(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
  end

  def _recv_lines(), do: _recv_lines(1)
  def _recv_lines(:until_timeout), do: _recv_lines(99999)

  def _recv_lines(lines) do
    receive do
      value ->
        cond do
          is_tuple(value) ->
            _recv_lines(lines)

          true ->
            case lines do
              1 -> value
              _ -> value <> _recv_lines(lines - 1)
            end
        end
    after
      500 ->
        ""
    end
  end

  def _recv_raw(socket = {:sslsocket, _, _}) do
    case :ssl.recv(socket, 0, 500) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end

  def _recv_raw(socket) do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} -> reply |> to_string
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end

  def _recv_binary(socket) do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} -> reply
      {:error, :timeout} -> :timeout
      {:error, :closed} -> :closed
    end
  end

  def _recv_until(socket), do: _recv_until(socket, "")

  def _recv_until(socket = {:sslsocket, _, _}, acc) do
    case :ssl.recv(socket, 0, 1000) do
      {:ok, reply} ->
        _recv_until(socket, acc <> to_string(reply))

      {:error, :timeout} ->
        acc
    end
  end

  def _recv_until(socket, acc) do
    case :gen_tcp.recv(socket, 0, 1000) do
      {:ok, reply} ->
        _recv_until(socket, acc <> to_string(reply))

      {:error, :timeout} ->
        acc
    end
  end

  def _tachyon_send(socket, data) do
    msg = TachyonLib.encode(data)
    _send_raw(socket, msg <> "\n")
  end

  def _tachyon_recv(socket) do
    case _recv_raw(socket) do
      :timeout ->
        :timeout

      :closed ->
        :closed

      resp ->
        resp
        |> String.split("\n")
        |> Enum.map(fn line ->
          case TachyonLib.decode(line) do
            {:ok, msg} -> msg
            error -> error
          end
        end)
        |> Enum.filter(fn r -> r != nil end)
    end
  end

  def _tachyon_recv_until(socket), do: _tachyon_recv_until(socket, [])

  def _tachyon_recv_until(socket = {:sslsocket, _, _}, acc) do
    case :ssl.recv(socket, 0, 500) do
      {:ok, reply} ->
        resp =
          reply
          |> to_string
          |> String.split("\n")
          |> Enum.map(fn line ->
            case TachyonLib.decode(line) do
              {:ok, msg} -> msg
              error -> error
            end
          end)
          |> Enum.filter(fn r -> r != nil end)

        _tachyon_recv_until(socket, acc ++ resp)

      {:error, :timeout} ->
        acc
    end
  end

  def mock_socket() do
    %{
      mock: true,
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
      lobby_host: false,
      user: nil,
      queues: [],
      ready_queue_id: nil,

      # Connection microstate
      lobby_id: nil,
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      print_client_messages: false,
      print_server_messages: false,
      exempt_from_cmd_throttle: true,
      script_password: nil,
      pending_messages: []
    }
  end

  def mock_state_auth(protocol_in, protocol_out, socket \\ nil) do
    socket = if socket, do: socket, else: mock_socket()
    user = new_user()
    Client.login(user, :test, "127.0.0.1")

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
      lobby_host: false,
      user: user,

      # Connection microstate
      lobby_id: nil,
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      print_client_messages: false,
      print_server_messages: false,
      exempt_from_cmd_throttle: true,
      script_password: nil,
      pending_messages: []
    }
  end

  defp make_async_transport() do
    send = fn _x, _y -> nil end

    %{
      send: send
    }
  end

  def mock_async_state(protocol_in, protocol_out, user \\ nil) do
    socket = mock_socket()
    user = if user, do: user, else: new_user()

    %{
      # Testing specific
      mock: true,
      test_pid: self(),

      # Connection state
      message_part: "",
      last_msg: System.system_time(:second) - 5,
      socket: socket,
      transport: make_async_transport(),
      protocol_in: protocol_in,
      protocol_out: protocol_out,
      ip: "127.0.0.1",

      # Client state
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,

      # Connection microstate
      lobby_id: nil,
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      print_client_messages: false,
      print_server_messages: false,
      exempt_from_cmd_throttle: true,
      script_password: nil
    }
  end

  @spec conn_setup({:ok, List.t()}) :: {:ok, List.t()}
  def conn_setup({:ok, data}) do
    user = data[:user]
    User.recache_user(user.id)

    Account.create_group_membership(%{
      user_id: user.id,
      group_id: Teiserver.user_group_id()
    })

    {:ok, data}
  end

  @spec admin_permissions() :: [String.t()]
  def admin_permissions do
    permissions =
      ~w(account battle clan queue)
      |> Enum.map(fn p -> "teiserver.admin.#{p}" end)

    permissions ++ staff_permissions()
  end

  @spec staff_permissions() :: [String.t()]
  def staff_permissions do
    m_permissions =
      ~w(account battle clan queue moderator reviewer telemetry)
      |> Enum.map(fn p -> "teiserver.staff.#{p}" end)

    permissions =
      ~w(moderator communication)
      |> Enum.map(fn p -> "teiserver.staff.#{p}" end)

    permissions ++ m_permissions ++ player_permissions()
  end

  @spec player_permissions() :: [String.t()]
  def player_permissions do
    ["teiserver.player.account"]
  end

  @spec make_clan(String.t(), Map.t()) :: Teiserver.Clans.Clan.t()
  def make_clan(name, params \\ %{}) do
    {:ok, c} =
      Teiserver.Clans.create_clan(
        Map.merge(
          %{
            "name" => name,
            "tag" => "[#{name}]",
            "icon" => "fa far-house",
            "colour" => "#001122",
            "description" => "Description goes here",
            "data" => %{}
          },
          params
        )
      )

    c
  end

  @spec make_clan_membership(Integer.t(), Integer.t(), Map.t()) ::
          Teiserver.Clans.ClanMembership.t()
  def make_clan_membership(clan_id, user_id, data \\ %{}) do
    {:ok, gm} =
      Teiserver.Clans.create_clan_membership(%{
        "clan_id" => clan_id,
        "user_id" => user_id,
        "role" => data["role"] || "Member"
      })

    gm
  end

  @spec make_queue(String.t(), Map.t()) :: Teiserver.Game.Queue.t()
  def make_queue(name, params \\ %{}) do
    {:ok, q} =
      Teiserver.Game.create_queue(
        Map.merge(
          %{
            "name" => name,
            "team_size" => 1,
            "icon" => "fa far-house",
            "colour" => "#112233",
            "settings" => %{},
            "conditions" => %{},
            "map_list" => []
          },
          params
        )
      )

    q
  end

  @spec make_battle(Map.t()) :: Map.t()
  def make_battle(params \\ %{}) do
    id = :rand.uniform(99_999_999) + 1_000_000

    %{
      founder_id: id,
      founder_name: "TEST_USER_#{id}",
      name: "BATTLE_#{id}",
      type: "normal",
      nattype: :none,
      port: "",
      max_players: 4,
      game_hash: "game_hash",
      map_hash: "map_hash",
      password: nil,
      rank: 0,
      locked: false,
      engine_name: "engine_name",
      engine_version: "engine_version",
      map_name: "map_name",
      game_name: "game_name",
      ip: "127.0.0.1"
    }
    |> Map.merge(params)
    |> Teiserver.Battle.Lobby.create_lobby()
    |> Teiserver.Battle.Lobby.add_lobby()
  end

  defp seed_badge_types() do
    # Create the badge types
    if Enum.empty?(AccoladeLib.get_badge_types()) do
      {:ok, _badge_type1} =
        Account.create_badge_type(%{
          name: "Badge A",
          icon: "i",
          colour: "c",
          purposes: ["Accolade"],
          description: "Description for the first badge"
        })

      {:ok, _badge_type2} =
        Account.create_badge_type(%{
          name: "Badge B",
          icon: "i",
          colour: "c",
          purposes: ["Accolade"],
          description: "Description for the second badge"
        })

      {:ok, _badge_type3} =
        Account.create_badge_type(%{
          name: "Badge C",
          icon: "i",
          colour: "c",
          purposes: ["Accolade"],
          description: "Description for the third badge"
        })
    end
  end

  def seed() do
    CoordinatorServer.get_coordinator_account()
    Teiserver.Account.AccoladeBotServer.get_accolade_account()

    Teiserver.Account.get_or_add_smurf_key_type("client_app_hash")
    Teiserver.Account.get_or_add_smurf_key_type("chobby_hash")
    Teiserver.Account.get_or_add_smurf_key_type("hw1")
    Teiserver.Account.get_or_add_smurf_key_type("hw2")

    Teiserver.Game.get_or_add_rating_type("Duel")
    Teiserver.Game.get_or_add_rating_type("Team")
    Teiserver.Game.get_or_add_rating_type("FFA")

    Teiserver.Telemetry.get_or_add_event_type("account.user_login")

    seed_badge_types()
  end
end
