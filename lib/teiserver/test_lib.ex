defmodule Teiserver.FakeTransport do
  @moduledoc false
  def send(_, _), do: nil
end

defmodule Teiserver.TeiserverTestLib do
  @moduledoc false
  alias Teiserver.User
  alias Teiserver.Client
  alias Teiserver.Account
  alias Teiserver.Protocols.Tachyon
  @host '127.0.0.1'

  @spec raw_setup :: %{socket: port()}
  def raw_setup() do
    {:ok, socket} = :gen_tcp.connect(@host, 8200, active: false)
    %{socket: socket}
  end

  def tls_setup() do
    {:ok, socket} = :ssl.connect(@host, 8201, active: false)
    %{socket: socket}
  end

  @spec new_user_name :: String.t()
  def new_user_name() do
    "new_test_user_#{:random.uniform(99_999_999) + 1_000_000}"
  end

  @spec new_user(any, any) :: atom | %{:id => any, optional(any) => any}
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

  @spec auth_setup(nil | Map.t()) :: %{socket: port(), user: Map.t()}
  def auth_setup(user \\ nil) do
    user = if user, do: user, else: new_user()

    {:ok, socket} = :gen_tcp.connect(@host, 8200, active: false)
    # Ignore the TASSERVER
    _ = _recv_raw(socket)

    # Now do our login
    _send_raw(
      socket,
      "LOGIN #{user.name} X03MO1qnZdYdgyfeuILPmQ== 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp\n"
    )

    _ = _recv_until(socket)

    %{socket: socket, user: user}
  end

  def _send_raw(socket = {:sslsocket, _, _}, msg) do
    :ok = :ssl.send(socket, msg)
    :timer.sleep(100)
  end

  def _send_raw(socket, msg) do
    :ok = :gen_tcp.send(socket, msg)
    :timer.sleep(100)
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

  def _recv_until(socket, acc \\ "") do
    case :gen_tcp.recv(socket, 0, 500) do
      {:ok, reply} ->
        _recv_until(socket, acc <> to_string(reply))

      {:error, :timeout} ->
        acc
    end
  end

  def _tachyon_send(socket, data) do
    msg = Tachyon.encode(data)
    :ok = :gen_tcp.send(socket, msg <> "\n")
    :timer.sleep(100)
  end

  def _tachyon_recv(socket) do
    case _recv_raw(socket) do
      :timeout ->
        :timeout

      resp ->
        case Tachyon.decode(resp) do
          {:ok, msg} -> msg
          error -> error
        end
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
      queues: [],
      ready_queue_id: nil,

      # Connection microstate
      battle_id: nil,
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      extra_logging: false,
      script_password: nil
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
      known_battles: [],
      extra_logging: false,
      script_password: nil
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
    permissions =
      ~w(account battle clan party queue tournament)
      |> Enum.map(fn p -> "teiserver.admin.#{p}" end)

    permissions ++ moderator_permissions()
  end

  @spec moderator_permissions() :: [String.t()]
  def moderator_permissions do
    permissions =
      ~w(account battle clan party queue tournament)
      |> Enum.map(fn p -> "teiserver.moderator.#{p}" end)

    permissions ++ player_permissions()
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
            "colour1" => "#001122",
            "colour2" => "#551122",
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
    id = :random.uniform(99_999_999) + 1_000_000

    %{
      founder_id: id,
      founder_name: "TEST_USER_#{id}",
      name: "BATTLE_#{id}",
      type: :normal,
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
    |> Teiserver.Battle.create_battle()
    |> Teiserver.Battle.add_battle()
  end
end
