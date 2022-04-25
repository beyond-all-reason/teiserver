defmodule Teiserver.TachyonTcpServer do
  @moduledoc false
  use GenServer
  require Logger
  alias Phoenix.PubSub
  alias Central.Config

  alias Teiserver.{User, Client}
  alias Teiserver.Data.Types, as: T

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
      protocol: Application.get_env(:central, Teiserver)[:default_tachyon_protocol],
      protocol_in: Application.get_env(:central, Teiserver)[:default_tachyon_protocol].protocol_in(),
      protocol_out: Application.get_env(:central, Teiserver)[:default_tachyon_protocol].protocol_out(),

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
      cmd_timestamps: [],

      # Caching app configs
      flood_rate_limit_count: Config.get_site_config_cache("teiserver.Tachyon flood rate limit count"),
      floot_rate_window_size: Config.get_site_config_cache("teiserver.Tachyon flood rate window size")
    }

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")

    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  @spec handle_call(any(), any(), T.tachyon_tcp_state()) :: {:reply, any(), T.tachyon_tcp_state()}
  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @spec handle_info(any(), T.tachyon_tcp_state()) :: {:noreply, T.tachyon_tcp_state()}
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

  # Instructions to update the state of the connection
  def handle_info({:action, {action_type, data}}, state) do
    new_state = case {action_type, data} do
      {:login_accepted, user_data} ->
        state.protocol.do_action(:login_accepted, user_data, state)

      {:host_lobby, lobby_id} ->
        state.protocol.do_action(:host_lobby, lobby_id, state)

      {:join_lobby, lobby_id} ->
        state.protocol.do_action(:join_lobby, lobby_id, state)

      {:leave_lobby, lobby_id} ->
        state.protocol.do_action(:leave_lobby, lobby_id, state)

      {:set_script_password, new_script_password} ->
        %{state | script_password: new_script_password}
    end

    {:noreply, new_state}
  end

  # Main source of data ingress
  def handle_info({:ssl, _socket, data}, state) do
    data = to_string(data)

    case flood_protect?(data, state) do
      {true, state} ->
        engage_flood_protection(state)
      {false, state} ->
        new_state = state.protocol_in.data_in(to_string(data), state)
        {:noreply, new_state}
    end
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

  # User updates
  def handle_info({:user_update, _event, _userid, _data}, state) do
    {:noreply, state}
  end

  # Depreciated/depreciating stuff, we just ignore it
  def handle_info({:request_user_join_lobby, _}, state), do: {:noreply, state}
  def handle_info({:join_battle_request_response, _, _, _}, state), do: {:noreply, state}
  def handle_info({:force_join_battle, _, _}, state), do: {:noreply, state}

  # Internal pubsub messaging (see pubsub.md)
  def handle_info({:server_event, event}, state) do
    {:noreply, state.protocol_out.reply(:system, :server_event, event, state)}
  end

  def handle_info({:lobby_host_message, event, lobby_id, data}, state) do
    if state.lobby_host == true and state.lobby_id == lobby_id do
      {:noreply, state.protocol_out.reply(:lobby_host, event, data, state)}
    else
      {:noreply, state}
    end
  end

  def handle_info({:lobby_chat, event, lobby_id, userid, data}, state) do
    {:noreply, state.protocol_out.reply(:lobby_chat, event, {lobby_id, userid, data}, state)}
  end

  def handle_info({:lobby_update, event, lobby_id, data}, state) do
    {:noreply, state.protocol_out.reply(:lobby, event, {lobby_id, data}, state)}
  end

  def handle_info({:client_message, event, userid, data}, state) do
    if state.userid == userid do
      case event do
        :join_lobby_request_response ->
          {:noreply, state.protocol_out.reply(:lobby, event, data, state)}

        :force_join_lobby ->
          {:noreply, state.protocol_out.reply(:lobby, event, data, state)}

        :received_direct_message ->
          {:noreply, state.protocol_out.reply(:communication, event, data, state)}

        :lobby_direct_announce ->
          {:noreply, state.protocol_out.reply(:lobby, :received_lobby_direct_announce, data, state)}

        :matchmaking ->
          {event, queue_id} = data
          {:noreply, state.protocol_out.reply(:matchmaking, event, queue_id, state)}

        _ ->
          {:noreply, state.protocol_out.reply(:client, event, data, state)}
      end
    else
      {:noreply, state}
    end
  end

  # Connection
  def handle_info({:ssl_closed, socket}, %{socket: socket, transport: transport} = state) do
    transport.close(socket)
    Client.disconnect(state.userid, ":ssl_closed with socket")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    Client.disconnect(state.userid, ":ssl_closed no socket")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info(:terminate, state) do
    Client.disconnect(state.userid, "tcp_server :terminate")
    {:stop, :normal, %{state | userid: nil}}
  end

  def terminate(_reason, state) do
    Client.disconnect(state.userid, "tcp_server terminate")
  end

  # Internal functions
  @spec flood_protect?(String.t(), map()) :: {boolean, map()}
  defp flood_protect?(_, %{exempt_from_cmd_throttle: true} = state), do: {false, state}
  defp flood_protect?(data, state) do
    cmd_timestamps = if String.contains?(data, "\n") do
      now = System.system_time(:second)
      limiter = now - state.floot_rate_window_size

      [now | state.cmd_timestamps]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)
    else
      state.cmd_timestamps
    end

    if Enum.count(cmd_timestamps) > state.flood_rate_limit_count do
      {true, %{state | cmd_timestamps: cmd_timestamps}}
    else
      {false, %{state | cmd_timestamps: cmd_timestamps}}
    end
  end

  defp engage_flood_protection(state) do
    state.protocol_out.reply(:disconnect, "Flood protection", nil, state)
    User.set_flood_level(state.userid, 10)
    Client.disconnect(state.userid, :flood)
    Logger.error("Tachyon command overflow from #{state.username}/#{state.userid} with #{Enum.count(state.cmd_timestamps)} commands. Disconnected and flood protection engaged.")
    {:stop, "Flood protection", state}
  end
end
