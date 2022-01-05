defmodule Teiserver.TachyonTcpServer do
  @moduledoc false
  use GenServer
  require Logger

  alias Teiserver.{User, Client}
  alias Teiserver.Tcp.{TcpLobby}

  # Duration refers to how long it will track commands for
  # Limit is the number of commands that can be sent in that time
  @cmd_flood_duration 10
  @cmd_flood_limit 20

  @behaviour :ranch_protocol
  @spec get_ssl_opts :: [
          {:cacertfile, String.t()} | {:certfile, String.t()} | {:keyfile, String.t()}
        ]
  def get_ssl_opts() do
    {certfile, cacertfile, keyfile} = {
      Application.get_env(:central, Teiserver)[:certs][:certfile],
      Application.get_env(:central, Teiserver)[:certs][:cacertfile],
      Application.get_env(:central, Teiserver)[:certs][:keyfile]
    }

    [
      certfile: certfile,
      cacertfile: cacertfile,
      keyfile: keyfile
    ]
  end

  # Called at startup
  def start_link(_opts) do
    ssl_opts = get_ssl_opts()

    :ranch.start_listener(
      make_ref(),
      :ranch_ssl,
      ssl_opts ++
        [
          {:port, Application.get_env(:central, Teiserver)[:ports][:tachyon]}
        ],
      __MODULE__,
      []
    )
  end

  # Called on new connection
  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport])
    {:ok, pid}
  end

  def init(ref, socket, transport) do
    {:ok, {ip, _}} = transport.peername(socket)

    ip =
      ip
      |> Tuple.to_list()
      |> Enum.join(".")

    :ranch.accept_ack(ref)
    transport.setopts(socket, [{:active, true}])

    heartbeat = Application.get_env(:central, Teiserver)[:heartbeat_interval]

    if heartbeat do
      :timer.send_interval(heartbeat, self(), :heartbeat)
    end

    state = %{
      # Connection state
      message_part: "",
      last_msg: System.system_time(:second),
      socket: socket,
      transport: transport,
      ip: ip,

      # Client state
      userid: nil,
      username: nil,
      lobby_host: false,
      user: nil,
      queues: [],
      ready_queue_id: nil,

      # Connection microstate
      msg_id: nil,
      lobby_id: nil,
      print_client_messages: false,
      print_server_messages: false,
      script_password: nil,
      exempt_from_cmd_throttle: true,
      cmd_timestamps: []
    }

    send(self(), {:action, {:welcome, nil}})
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  # If Ctrl + C is sent through it kills the connection, makes telnet debugging easier
  def handle_info({_, _socket, <<255, 244, 255, 253, 6>>}, state) do
    Client.disconnect(state.userid, "Terminal exit command")
    send(self(), :terminate)
    {:noreply, state}
  end

  # Main source of data ingress
  def handle_info({:tcp, _socket, data}, %{exempt_from_cmd_throttle: false} = state) do
    data = to_string(data)

    cmd_timestamps = if String.contains?(data, "\n") do
      now = System.system_time(:second)
      limiter = now - @cmd_flood_duration

      cmd_timestamps = [now | state.cmd_timestamps]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)

      if Enum.count(cmd_timestamps) > @cmd_flood_limit do
        User.set_flood_level(state.userid, 10)
        Client.disconnect(state.userid, :flood)
        Logger.error("Tachyon command overflow from #{state.username}/#{state.userid} with #{Enum.count(cmd_timestamps)} commands. Disconnected and flood protection engaged.")
      end

      cmd_timestamps
    else
      state.cmd_timestamps
    end

    new_state = state.protocol_in.data_in(data, state)
    {:noreply, %{new_state | cmd_timestamps: cmd_timestamps}}
  end
  def handle_info({:tcp, _socket, data}, %{exempt_from_cmd_throttle: true} = state) do
    new_state = state.protocol_in.data_in(to_string(data), state)
    {:noreply, new_state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = state.protocol_in.data_in(to_string(data), state)
    {:noreply, new_state}
  end

  # Email, when an email is sent we get a message, we don't care about that for the most part (yet)
  def handle_info({:delivered_email, _email}, state) do
    {:noreply, state}
  end

  # Heartbeat allows us to kill stale connections
  def handle_info(:heartbeat, state) do
    diff = System.system_time(:second) - state.last_msg

    if diff > Application.get_env(:central, Teiserver)[:heartbeat_timeout] do
      if state.username do
        Logger.error("Heartbeat timeout for #{state.username}")
      end
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end
end
