defmodule Teiserver.SpringTcpServer do
  @moduledoc false
  use GenServer
  require Logger

  alias Phoenix.PubSub
  alias Teiserver.Config
  alias Teiserver.{CacheUser, Client, Account, Room}
  alias Teiserver.Protocols.{SpringIn, SpringOut}
  alias Teiserver.Data.Types, as: T

  @init_timeout 60_000

  @behaviour :ranch_protocol
  @spec get_ssl_opts :: [
          {:cacertfile, String.t()} | {:certfile, String.t()} | {:keyfile, String.t()}
        ]
  def get_ssl_opts() do
    {certfile, cacertfile, keyfile} = {
      Application.get_env(:teiserver, Teiserver)[:certs][:certfile],
      Application.get_env(:teiserver, Teiserver)[:certs][:cacertfile],
      Application.get_env(:teiserver, Teiserver)[:certs][:keyfile]
    }

    [
      certfile: certfile,
      cacertfile: cacertfile,
      keyfile: keyfile
    ]
  end

  def get_standard_tcp_opts() do
    [
      max_connections: :infinity,
      nodelay: false,
      delay_send: true
    ]
  end

  # Called at startup
  def start_link(opts) do
    mode = if opts[:ssl], do: :ranch_ssl, else: :ranch_tcp

    # start_listener(Ref, Transport, TransOpts0, Protocol, ProtoOpts)
    if mode == :ranch_ssl do
      ssl_opts = get_ssl_opts()

      :ranch.start_listener(
        make_ref(),
        :ranch_ssl,
        ssl_opts ++
          get_standard_tcp_opts() ++
          [
            port: Application.get_env(:teiserver, Teiserver)[:ports][:tls]
          ],
        __MODULE__,
        []
      )
    else
      :ranch.start_listener(
        make_ref(),
        :ranch_tcp,
        get_standard_tcp_opts() ++
          [
            port: Application.get_env(:teiserver, Teiserver)[:ports][:tcp]
          ],
        __MODULE__,
        []
      )
    end
  end

  # Called on new connection
  @impl true
  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport])
    {:ok, pid}
  end

  def init(ref, socket, transport) do
    # https://www.erlang.org/docs/23/man/erlang#process_flag_max_heap_size
    # 20 MB = 20 * 1024 * 1024 / 8 words = 2_621_440 words (1 word = 8 bytes)
    Process.flag(:max_heap_size, 2_621_440)

    # If we've not started up yet, lets just delay for a moment
    # for some of the stuff to get sorted
    if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") !=
         true do
      :timer.sleep(1000)
    end

    {:ok, {ip, _}} = transport.peername(socket)

    ip =
      ip
      |> Tuple.to_list()
      |> Enum.join(".")

    :ranch.accept_ack(ref)
    transport.setopts(socket, [{:active, true}])

    heartbeat = Application.get_env(:teiserver, Teiserver)[:heartbeat_interval]

    if heartbeat do
      :timer.send_interval(heartbeat, self(), :heartbeat)
    end

    :timer.send_interval(60_000, self(), :message_count)

    # Set nodelay and delay_send values as the opts above don't always seem to do it
    case socket do
      {:sslsocket, {:gen_tcp, port, _, _}, _} ->
        :inet.setopts(port, [{:nodelay, false}, {:delay_send, true}])

      _ ->
        :inet.setopts(socket, [{:nodelay, false}, {:delay_send, true}])
    end

    state = %{
      # Connection state
      message_part: "",
      last_msg: System.system_time(:second),
      socket: socket,
      transport: transport,
      protocol_in:
        Application.get_env(:teiserver, Teiserver)[:default_spring_protocol].protocol_in(),
      protocol_out:
        Application.get_env(:teiserver, Teiserver)[:default_spring_protocol].protocol_out(),
      ip: ip,

      # Client state
      userid: nil,
      username: nil,
      lobby_host: false,
      user: nil,
      queues: [],
      ready_queue_id: nil,
      queued_userid: nil,

      # Connection microstate
      msg_id: nil,
      lobby_id: nil,
      party_id: nil,
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      print_client_messages: false,
      print_server_messages: false,
      script_password: nil,
      exempt_from_cmd_throttle: false,
      cmd_timestamps: [],
      status_timestamps: [],
      app_status: nil,
      protocol_optimisation: :full,
      pending_messages: [],

      # Caching app configs
      flood_rate_limit_count:
        Config.get_site_config_cache("teiserver.Spring flood rate limit count"),
      flood_rate_window_size:
        Config.get_site_config_cache("teiserver.Spring flood rate window size"),
      last_action_timestamp: nil,
      server_messages: 0,
      server_batches: 0,
      client_messages: 0
    }

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_server")

    redirect_url = Config.get_site_config_cache("system.Redirect url")

    if redirect_url != nil do
      SpringOut.reply(:redirect, redirect_url, nil, state)
      send(self(), :terminate)
      state
    else
      send(self(), {:action, {:welcome, nil}})

      if Config.get_site_config_cache("system.Disconnect unauthenticated sockets") do
        Process.send_after(self(), :init_timeout, @init_timeout)
      end

      :gen_server.enter_loop(__MODULE__, [], state)
    end
  end

  @impl true
  def init(init_arg) do
    {:ok, init_arg}
  end

  @impl true
  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  @impl true
  def handle_info(:init_timeout, %{userid: nil} = state) do
    send(self(), :terminate)
    {:noreply, state}
  end

  def handle_info(:init_timeout, state) do
    {:noreply, state}
  end

  # Anybody can have full optimisation
  def handle_info(:post_auth_check, %{protocol_optimisation: :full} = state) do
    {:noreply, state}
  end

  # Only chobby is allowed to have partial optimisation
  def handle_info(:post_auth_check, %{protocol_optimisation: :partial} = state) do
    if state.app_status != :accepted do
      user = Account.get_user_by_id(state.userid)

      if not CacheUser.is_bot?(user) do
        Logger.error("post_auth_check :partial - user is not accepted: #{user.id}/#{user.name}")
      end
    end

    {:noreply, state}
  end

  # Only bots are allowed to have no optimisation
  def handle_info(:post_auth_check, %{protocol_optimisation: :none} = state) do
    user = Account.get_user_by_id(state.userid)

    if not CacheUser.is_bot?(user) do
      Logger.error("post_auth_check :full - user is not bot: #{user.id}/#{user.name}")
    end

    {:noreply, state}
  end

  def handle_info(:message_count, state) do
    Teiserver.Telemetry.cast_to_server({
      :spring_messages_sent,
      state.userid,
      state.server_messages,
      state.server_batches,
      state.client_messages
    })

    {:noreply, %{state | server_messages: 0, client_messages: 0, server_batches: 0}}
  end

  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  # If Ctrl + C is sent through it kills the connection, makes telnet debugging easier
  def handle_info({_, _socket, <<255, 244, 255, 253, 6>>}, state) do
    SpringOut.reply(:disconnect, "Ctrl + C", nil, state)
    Client.disconnect(state.userid, "Terminal exit command")
    send(self(), :terminate)
    {:noreply, state}
  end

  # Main source of data ingress
  def handle_info({:tcp, _socket, data}, state) do
    data = to_string(data)

    case flood_protect?(data, state) do
      {true, state} ->
        engage_flood_protection(state)

      {false, state} ->
        new_state = SpringIn.data_in(data, state)
        {:noreply, %{new_state | client_messages: state.client_messages + 1}}
    end
  end

  def handle_info({:ssl, _socket, data}, state) do
    data = to_string(data)

    case flood_protect?(data, state) do
      {true, state} ->
        engage_flood_protection(state)

      {false, state} ->
        new_state = SpringIn.data_in(data, state)
        {:noreply, %{new_state | client_messages: state.client_messages + 1}}
    end

    # new_state = SpringIn.data_in(to_string(data), state)
    # {:noreply, new_state}
  end

  # Email, when an email is sent we get a message, we don't care about that for the most part (yet)
  def handle_info({:delivered_email, _email}, state) do
    {:noreply, state}
  end

  def handle_info(:server_sent_message, state) do
    {:noreply, %{state | server_messages: state.server_messages + 1}}
  end

  # Heartbeat allows us to kill stale connections
  def handle_info(:heartbeat, state) do
    diff = System.system_time(:second) - state.last_msg

    if diff > Application.get_env(:teiserver, Teiserver)[:heartbeat_timeout] do
      SpringOut.reply(:disconnect, "Heartbeat", nil, state)

      if state.username do
        Logger.info("Heartbeat timeout for #{state.username}")
      end

      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  def handle_info({:action, {action_type, data}}, state) do
    new_state = do_action(action_type, data, state)
    {:noreply, new_state}
  end

  # Server messages
  def handle_info(%{channel: "teiserver_server", event: "stop"}, state) do
    coordinator_id = Teiserver.Coordinator.get_coordinator_userid()

    state = SpringOut.reply(:server_restart, nil, nil, state)

    state =
      new_chat_message(
        :direct_message,
        coordinator_id,
        nil,
        "Teiserver update taking place, see discord for details/issues.",
        state
      )

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state) do
    {:noreply, state}
  end

  # Client channel messages
  def handle_info(
        %{channel: "teiserver_client_messages:" <> _, event: :lobby_direct_announce} = msg,
        state
      ) do
    SpringOut.reply(
      :battle_message_ex,
      {msg.sender_id, msg.message_content, msg.lobby_id, state.userid},
      nil,
      state
    )

    {:noreply, state}
  end

  def handle_info(
        %{channel: "teiserver_client_messages:" <> _userid_str, party_id: _party_id} = event,
        state
      ) do
    # I am taking a shortcut here. There may already be something in place to
    # react to random events and delegating that to a handler.
    # This is bypassing SpringIn entirely
    state = Teiserver.Protocols.Spring.PartyIn.handle_event(event, state)
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_party:" <> _party_id} = event, state) do
    # I am taking a shortcut here. There may already be something in place to
    # react to random events and delegating that to a handler.
    # This is bypassing SpringIn entirely
    state = Teiserver.Protocols.Spring.PartyIn.handle_event(event, state)
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _userid_str}, state) do
    {:noreply, state}
  end

  # Relationship messages
  def handle_info(%{channel: "account_user_relationships:" <> _id} = msg, state) do
    SpringOut.reply(:user, msg.event, msg, nil, state)
    {:noreply, state}
  end

  def handle_info(
        %{
          channel: "teiserver_global_lobby_updates",
          event: :updated_values,
          lobby_id: lobby_id,
          new_values: new_values
        },
        state
      ) do
    new_state =
      if Map.has_key?(new_values, :name) do
        SpringOut.reply(:battle, :lobby_rename, lobby_id, nil, state)
      else
        keys = Map.keys(new_values)

        if Enum.member?(keys, :locked) or Enum.member?(keys, :map_name) or
             Enum.member?(keys, :spectator_count) do
          SpringOut.reply(:update_battle, lobby_id, nil, state)
        else
          state
        end
      end

    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_global_lobby_updates", event: :opened, lobby: nil}, state) do
    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_global_lobby_updates", event: :opened} = msg, state) do
    lobby_id = msg.lobby.id

    state =
      if state.lobby_host == false or state.lobby_id != lobby_id do
        new_known_battles = [lobby_id | state.known_battles]
        new_state = %{state | known_battles: new_known_battles}
        SpringOut.reply(:battle_opened, msg.lobby, nil, new_state)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_global_lobby_updates", event: :closed} = msg, state) do
    lobby_id = msg.lobby_id

    state =
      if Enum.member?(state.known_battles, lobby_id) do
        new_known_battles = List.delete(state.known_battles, lobby_id)
        new_state = %{state | known_battles: new_known_battles}
        SpringOut.reply(:battle_closed, lobby_id, nil, new_state)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(
        %{channel: "teiserver_global_lobby_updates", event: :updated_values} = msg,
        state
      ) do
    lobby_id = msg.lobby_id

    state =
      if Enum.member?(state.known_battles, lobby_id) do
        new_known_battles = List.delete(state.known_battles, lobby_id)
        new_state = %{state | known_battles: new_known_battles}
        SpringOut.reply(:battle_closed, lobby_id, nil, new_state)
      else
        state
      end

    {:noreply, state}
  end

  def handle_info(:error_log, state) do
    new_state = SpringOut.reply(:error_log, :error_log, nil, state)
    {:noreply, new_state}
  end

  # We were not able to login right away, instead we had to queue for a bit!
  def handle_info({:login_accepted, userid}, state) do
    user = Account.get_user_by_id(userid)
    new_state = SpringOut.do_login_accepted(state, user, state.lobby)

    # Do we have a clan?
    if user.clan_id do
      :timer.sleep(200)
      clan = Teiserver.Clans.get_clan!(user.clan_id)
      room_name = Room.clan_room_name(clan.tag)
      SpringOut.do_join_room(new_state, room_name)
    end

    if state.lobby_hash == nil do
      send(self(), :terminate)
    else
      {:ok, _user} = CacheUser.do_login(user, state.ip, state.lobby, state.lobby_hash)
    end

    {:noreply, new_state}
  end

  # Client updates
  # def handle_info({:user_logged_in, nil}, state), do: {:noreply, state}

  # def handle_info({:user_logged_in, userid}, state) do
  #   new_state = user_logged_in(userid, state)
  #   {:noreply, new_state}
  # end

  # # Some logic because if we're the one logged out we need to disconnect
  # def handle_info({:user_logged_out, userid, username}, state) do
  #   if state.userid == userid do
  #     SpringOut.reply(:disconnect, "Logged out", nil, state)
  #     {:stop, :normal, state}
  #   else
  #     new_state = user_logged_out(userid, username, state)
  #     {:noreply, new_state}
  #   end
  # end

  def handle_info({:updated_client, new_client, reason}, state) do
    new_state =
      case reason do
        :client_updated_status ->
          client_status_update(new_client, state)

        :client_updated_battlestatus ->
          client_battlestatus_update(new_client, state)
      end

    {:noreply, new_state}
  end

  # User
  def handle_info({:this_user_updated, fields}, state) do
    new_state = user_updated(fields, state)
    {:noreply, new_state}
  end

  # This is used only as part of the login process to keep stuff in a certain order
  def handle_info({:spring_add_user_from_login, client}, state) do
    new_state = user_added_at_login(client, state)
    {:noreply, new_state}
  end

  # Matchmaking
  # def handle_info({:matchmaking, data}, state) do
  #   new_state = matchmaking_update(data, state)
  #   {:noreply, new_state}
  # end

  # Chat
  def handle_info({:direct_message, from, msg}, state) do
    new_state = new_chat_message(:direct_message, from, nil, msg, state)
    {:noreply, new_state}
  end

  def handle_info({:new_message, from, room_name, msg}, state) do
    new_state = new_chat_message(:chat_message, from, room_name, msg, state)
    {:noreply, new_state}
  end

  def handle_info({:new_message_ex, from, room_name, msg}, state) do
    new_state = new_chat_message(:chat_message_ex, from, room_name, msg, state)
    {:noreply, new_state}
  end

  def handle_info({:add_user_to_room, userid, room_name}, state) do
    new_state = user_join_chat_room(userid, room_name, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_room, userid, room_name}, state) do
    new_state = user_leave_chat_room(userid, room_name, state)
    {:noreply, new_state}
  end

  # Client in-out
  def handle_info(%{channel: "client_inout", event: :login} = msg, state) do
    new_state = user_logged_in(msg.client, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "client_inout", event: :disconnect} = msg, state) do
    if state.userid == msg.userid do
      new_state = SpringOut.reply(:disconnect, "Logged out", nil, state)
      {:stop, :normal, new_state}
    else
      username = Account.get_username(msg.userid)
      new_state = user_logged_out(msg.userid, username, state)
      {:noreply, new_state}
    end
  end

  # Lobbies
  def handle_info(%{channel: "teiserver_lobby_updates", event: :updated_queue} = msg, state) do
    new_state = SpringOut.reply(:battle, :queue_status, {msg.lobby_id, msg.id_list}, nil, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_lobby_updates"} = msg, state) do
    new_state = battle_update(msg, state)
    {:noreply, new_state}
  end

  # Lobby chat
  def handle_info(%{channel: "teiserver_lobby_chat:" <> _, event: :say} = msg, state) do
    new_data = {msg.userid, msg.message, msg.lobby_id, state.userid}
    new_state = SpringOut.reply(:battle_message, new_data, nil, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_lobby_chat:" <> _, event: :announce} = msg, state) do
    new_data = {msg.userid, msg.message, msg.lobby_id, state.userid}
    new_state = SpringOut.reply(:battle_message_ex, new_data, nil, state)
    {:noreply, new_state}
  end

  def handle_info({:request_user_join_lobby, userid}, state) do
    new_state = request_user_join_lobby(userid, state)
    {:noreply, new_state}
  end

  def handle_info({:join_battle_request_response, lobby_id, response, reason}, state) do
    new_state = join_battle_request_response(lobby_id, response, reason, state)
    {:noreply, new_state}
  end

  def handle_info({:force_join_battle, lobby_id, script_password}, state) do
    new_state = force_join_battle(lobby_id, script_password, state)
    {:noreply, new_state}
  end

  def handle_info({:login_event, :add_user_to_battle, userid, lobby_id}, state) do
    client = Account.get_client_by_id(userid)
    new_state = user_join_battle(client, lobby_id, nil, state)
    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :joined_lobby} = msg,
        %{protocol_optimisation: :full} = state
      ) do
    new_state =
      if state.lobby_id != nil and msg.lobby_id == state.lobby_id do
        user_join_battle(msg.client, msg.lobby_id, msg.script_password, state)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :joined_lobby} = msg,
        %{protocol_optimisation: :partial} = state
      ) do
    new_state = user_join_battle(msg.client, msg.lobby_id, msg.script_password, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_global_user_updates", event: :joined_lobby} = msg, state) do
    new_state = user_join_battle(msg.client, msg.lobby_id, msg.script_password, state)
    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :left_lobby} = msg,
        %{protocol_optimisation: :full} = state
      ) do
    new_state =
      if state.lobby_id != nil and msg.lobby_id == state.lobby_id do
        user_leave_battle(msg.client, msg.lobby_id, state)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :left_lobby} = msg,
        %{protocol_optimisation: :partial} = state
      ) do
    new_state = user_leave_battle(msg.client, msg.lobby_id, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_global_user_updates", event: :left_lobby} = msg, state) do
    new_state = user_leave_battle(msg.client, msg.lobby_id, state)
    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :kicked_from_lobby} = msg,
        %{protocol_optimisation: :full} = state
      ) do
    new_state =
      if state.lobby_id != nil and msg.lobby_id == state.lobby_id do
        user_kicked_from_battle(msg.client, msg.lobby_id, state)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :kicked_from_lobby} = msg,
        %{protocol_optimisation: :partial} = state
      ) do
    new_state = user_kicked_from_battle(msg.client, msg.lobby_id, state)
    {:noreply, new_state}
  end

  def handle_info(
        %{channel: "teiserver_global_user_updates", event: :kicked_from_lobby} = msg,
        state
      ) do
    new_state = user_kicked_from_battle(msg.client, msg.lobby_id, state)
    {:noreply, new_state}
  end

  def handle_info(%{channel: "teiserver_global_user_updates"}, state) do
    {:noreply, state}
  end

  # Timeout error
  def handle_info(
        {:tcp_error, _port, :etimedout},
        %{socket: socket, transport: transport} = state
      ) do
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with tcp_error :etimedout")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info(
        {:tcp_error, _port, :ehostunreach},
        %{socket: socket, transport: transport} = state
      ) do
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with tcp_error :ehostunreach")
    {:stop, :normal, %{state | userid: nil}}
  end

  # Connection
  def handle_info({:tcp_closed, _socket}, %{socket: socket, transport: transport} = state) do
    SpringOut.reply(:disconnect, "TCP Closed", nil, state)
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with socket")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    SpringOut.reply(:disconnect, "TCP Closed", nil, state)
    Client.disconnect(state.userid, ":tcp_closed no socket")
    {:stop, :normal, %{state | userid: nil}}
  end

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
    new_state = SpringOut.reply(:disconnect, "Terminate", nil, state)
    Client.disconnect(new_state.userid, "tcp_server :terminate")
    {:stop, :normal, %{new_state | userid: nil}}
  end

  @impl true
  def terminate(_reason, state) do
    Client.disconnect(state.userid, "tcp_server terminate")
  end

  # #############################
  # Internal functions
  # #############################
  # User updates
  defp user_logged_in(client, state) do
    known_users =
      case state.known_users[client.userid] do
        nil ->
          SpringOut.reply(:user_logged_in, client, nil, state)
          Map.put(state.known_users, client.userid, _blank_user(client.userid))

        _ ->
          state.known_users
      end

    %{state | known_users: known_users}
  end

  defp user_added_at_login(client, state) do
    known_users =
      case state.known_users[client.userid] do
        nil ->
          SpringOut.reply(:add_user, client, nil, state)
          Map.put(state.known_users, client.userid, _blank_user(client.userid))

        _ ->
          state.known_users
      end

    %{state | known_users: known_users}
  end

  defp user_logged_out(userid, username, state) do
    {known_users, room_member_cache} =
      case state.known_users[userid] do
        nil ->
          {state.known_users, state.room_member_cache}

        _ ->
          # Remove from rooms
          new_room_member_cache =
            state.room_member_cache
            |> Map.new(fn {room_name, members} ->
              if Enum.member?(members, userid) do
                SpringOut.reply(:remove_user_from_room, {userid, room_name}, nil, state)
                new_members = List.delete(members, userid)
                {room_name, new_members}
              else
                {room_name, members}
              end
            end)

          SpringOut.reply(:user_logged_out, {userid, username}, nil, state)
          {Map.delete(state.known_users, userid), new_room_member_cache}
      end

    %{state | known_users: known_users, room_member_cache: room_member_cache}
  end

  defp user_updated(fields, state) do
    new_user = CacheUser.get_user_by_id(state.userid)
    new_state = %{state | user: new_user}

    fields
    |> Enum.each(fn field ->
      case field do
        :friends ->
          SpringOut.reply(:friendlist, state.userid, nil, state)

        :friend_requests ->
          SpringOut.reply(:friendlist_request, state.userid, nil, state)

        :ignored ->
          SpringOut.reply(:ignorelist, state.userid, nil, state)

        _ ->
          Logger.error("No handler in tcp_server:user_updated with field #{field}")
      end
    end)

    new_state
  end

  # Client updates
  defp client_status_update(new_client, %{protocol_optimisation: :full} = state) do
    send_status =
      [
        state.lobby_id != nil and new_client.lobby_id == state.lobby_id,
        new_client.bot == true,
        new_client.moderator == true
      ]
      |> Enum.any?()

    if send_status do
      do_client_status_update(new_client, state)
    else
      state
    end
  end

  defp client_status_update(new_client, %{protocol_optimisation: :partial} = state) do
    do_client_status_update(new_client, state)
  end

  defp client_status_update(new_client, state) do
    do_client_status_update(new_client, state)
  end

  defp do_client_status_update(%{userid: userid} = new_client, state) do
    if state.known_users[userid] == nil do
      state = SpringOut.reply(:user_logged_in, new_client, nil, state)
      new_user = _blank_user(userid)
      new_knowns = Map.put(state.known_users, userid, new_user)
      %{state | known_users: new_knowns}
    else
      SpringOut.reply(:client_status, new_client, nil, state)
    end
  end

  defp client_battlestatus_update(%{lobby_id: _} = new_client, state) do
    if state.lobby_id != nil and state.lobby_id == new_client.lobby_id do
      SpringOut.reply(:client_battlestatus, new_client, nil, state)
    else
      state
    end
  end

  defp client_battlestatus_update(_, state) do
    state
  end

  # Battle updates
  defp battle_update(%{event: :update_values} = msg, state) do
    cond do
      msg.changes == nil ->
        SpringOut.reply(:update_battle, msg.lobby_id, nil, state)

      msg.changes == %{disabled_units: []} and state.lobby_id == msg.lobby_id ->
        SpringOut.reply(:enable_all_units, [], nil, state)

      Map.has_key?(msg.changes, :disabled_units) and state.lobby_id == msg.lobby_id ->
        SpringOut.reply(:enable_all_units, [], nil, state)
        SpringOut.reply(:disable_units, msg.changes.disabled_units, nil, state)

      true ->
        SpringOut.reply(:update_battle, msg.lobby_id, nil, state)
    end
  end

  defp battle_update(msg, state) do
    case msg.event do
      :add_start_area ->
        SpringOut.reply(:add_start_rectangle, {msg.area_id, msg.area}, nil, state)

      :remove_start_area ->
        SpringOut.reply(:remove_start_rectangle, msg.area_id, nil, state)

      :set_modoptions ->
        SpringOut.reply(:add_script_tags, msg.options, nil, state)

      :remove_modoptions ->
        SpringOut.reply(:remove_script_tags, msg.keys, nil, state)

      :add_bot ->
        SpringOut.reply(:add_bot_to_battle, {msg.lobby_id, msg.bot}, nil, state)

      :update_bot ->
        SpringOut.reply(:update_bot, {msg.lobby_id, msg.bot}, nil, state)

      :remove_bot ->
        SpringOut.reply(:remove_bot_from_battle, {msg.lobby_id, msg.bot}, nil, state)

      :remove_user ->
        state = user_leave_battle(msg.client, msg.lobby_id, state)
        SpringOut.reply(:update_battle, msg.lobby_id, nil, state)
        state

      :kick_user ->
        user_kicked_from_battle(msg.client, msg.lobby_id, state)

      :add_user ->
        script_password =
          if msg.client.userid == state.userid do
            state.script_password
          else
            msg.script_password
          end

        state = user_join_battle(msg.client, msg.lobby_id, script_password, state)
        SpringOut.reply(:update_battle, msg.lobby_id, nil, state)
        state

      :updated_client_battlestatus ->
        client_battlestatus_update(msg.client, state)

      :closed ->
        state

      :updated ->
        SpringOut.reply(:update_battle, msg.lobby_id, nil, state)
        state

      _ ->
        raise "No handler in tcp_server:battle_update with reason #{msg.event}"
        Logger.error("No handler in tcp_server:battle_update with reason #{msg.event}")
        state
    end
  end

  # This is the server asking the host if a client can join the battle
  # the client is expected to reply with a yes or no
  defp request_user_join_lobby(userid, state) do
    SpringOut.reply(:request_user_join_lobby, userid, nil, state)
  end

  # This is the result of the host responding to the server asking if the client
  # can join the battle
  defp join_battle_request_response(nil, _, _, state) do
    SpringOut.reply(:join_battle_failure, "No battle", nil, state)
  end

  defp join_battle_request_response(lobby_id, response, reason, state) do
    case response do
      :accept ->
        SpringOut.do_join_battle(state, lobby_id, state.script_password)

      :deny ->
        SpringOut.reply(:join_battle_failure, reason, nil, state)
    end
  end

  # This is the result of being forced to join a battle
  defp force_join_battle(lobby_id, script_password, state) do
    new_state = SpringOut.do_leave_battle(state, state.lobby_id)
    new_state = %{new_state | lobby_id: lobby_id, script_password: script_password}
    SpringOut.do_join_battle(new_state, lobby_id, script_password)
  end

  # Depending on our current understanding of where the user is
  # we will send a selection of commands on the assumption this
  # genserver is incorrect and needs to alter its state accordingly
  @spec user_join_battle(T.client(), T.lobby_id(), String.t(), T.spring_tcp_state()) ::
          T.spring_tcp_state()
  defp user_join_battle(nil, _, _, state) do
    state
  end

  defp user_join_battle(%{userid: userid} = client, lobby_id, script_password, state) do
    # If someone joins the battle, update their status for ourselves
    state = do_client_status_update(client, state)

    script_password =
      cond do
        state.lobby_host and state.lobby_id == lobby_id -> script_password
        state.userid == userid -> script_password
        true -> nil
      end

    new_user =
      cond do
        # Case 1, we are the user
        state.userid == userid ->
          _blank_user(userid, %{lobby_id: lobby_id})

        # Case 2, we do not know about the user
        # User isn't known about so we say they've logged in
        # Then we add them to the battle
        state.known_users[userid] == nil ->
          SpringOut.reply(:user_logged_in, client, nil, state)

          SpringOut.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          _blank_user(userid, %{lobby_id: lobby_id})

        # Case 3, we know the user, they are not in a lobby
        state.known_users[userid].lobby_id == nil ->
          SpringOut.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: lobby_id}

        # Case 4, we know the user, they are in a different lobby
        state.known_users[userid].lobby_id != lobby_id ->
          # If we don't know about the battle we don't need to remove the user from it first
          if Enum.member?(state.known_battles, state.known_users[userid].lobby_id) do
            SpringOut.reply(
              :remove_user_from_battle,
              {userid, state.known_users[userid].lobby_id},
              nil,
              state
            )
          end

          SpringOut.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: lobby_id}

        # Case 5, we know the user, they are in the correct lobby
        state.known_users[userid].lobby_id == lobby_id ->
          state.known_users[userid]
      end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_leave_battle(nil, _, state) do
    state
  end

  defp user_leave_battle(client, lobby_id, state) do
    # If they are kicked then it's possible they won't be unsubbed
    userid = client.userid

    if userid == state.userid do
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{lobby_id}")
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{lobby_id}")
    end

    # Do they know about the battle?
    state =
      if Enum.member?(state.known_battles, lobby_id) do
        state
      else
        SpringOut.reply(:battle_opened, lobby_id, nil, state)
      end

    # Now the user
    new_user =
      cond do
        # Case 1 - We don't know about the battle? Ignore it
        Enum.member?(state.known_battles, lobby_id) == false ->
          state.known_users[userid]

        # Case 2 - We don't even know who they are? Leave it too
        state.known_users[userid] == nil ->
          SpringOut.reply(:user_logged_in, client, nil, state)
          _blank_user(userid)

        # Case 3 - We know them but not that they were in the lobby?
        state.known_users[userid].lobby_id == nil ->
          # No change
          state.known_users[userid]

        state.known_users[userid].lobby_id != nil ->
          # We don't care which battle we thought they are in, they're no longer in it
          SpringOut.reply(
            :remove_user_from_battle,
            {userid, state.known_users[userid].lobby_id},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: nil}

        true ->
          Logger.error("user_leave_battle default case #{inspect(state.known_users[userid])}")
          state.known_users[userid]
      end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_kicked_from_battle(client, lobby_id, state) do
    # If it's the user, we need to tell them the bad news
    state =
      if client.userid == state.userid do
        SpringOut.reply(:forcequit_battle, nil, nil, state)
        %{state | lobby_id: nil}
      else
        state
      end

    user_leave_battle(client, lobby_id, state)
  end

  # Chat
  defp new_chat_message(type, from, room_name, msg, state) do
    # This allows us to see messages sent by web-users
    client =
      case Client.get_client_by_id(from) do
        nil ->
          user = Account.get_user_by_id(from)

          Client.create(%{
            userid: user.id,
            name: user.name,
            rank: 0,
            moderator: CacheUser.is_moderator?(user),
            bot: CacheUser.is_bot?(user)
          })

        c ->
          c
      end

    # Do they know about the user?
    state =
      case Map.has_key?(state.known_users, from) do
        false ->
          SpringOut.reply(:user_logged_in, client, nil, state)
          %{state | known_users: Map.put(state.known_users, from, _blank_user(from))}

        true ->
          state
      end

    # Now handle the message itself
    case type do
      :direct_message ->
        SpringOut.reply(:direct_message, {from, msg, state.user}, nil, state)

      :chat_message ->
        SpringOut.reply(
          :chat_message,
          {from, room_name, msg, state.user},
          nil,
          state
        )

      :chat_message_ex ->
        SpringOut.reply(
          :chat_message_ex,
          {from, room_name, msg, state.user},
          nil,
          state
        )
    end
  end

  defp user_join_chat_room(userid, room_name, state) do
    case Client.get_client_by_id(userid) do
      nil ->
        # No client? Ignore them
        state

      client ->
        # Do they know about the user?
        state =
          case Map.has_key?(state.known_users, userid) do
            false ->
              SpringOut.reply(:user_logged_in, client, nil, state)
              %{state | known_users: Map.put(state.known_users, userid, _blank_user(userid))}

            true ->
              state
          end

        new_members =
          if Enum.member?(state.room_member_cache[room_name] || [], userid) do
            state.room_member_cache[room_name] || []
          else
            SpringOut.reply(:add_user_to_room, {userid, room_name}, nil, state)
            [userid | state.room_member_cache[room_name] || []]
          end

        new_cache = Map.put(state.room_member_cache, room_name, new_members)
        %{state | room_member_cache: new_cache}
    end
  end

  defp user_leave_chat_room(userid, room_name, state) do
    case Map.has_key?(state.known_users, userid) do
      false ->
        # We don't know who they are, we don't care they've left the chat room
        state

      true ->
        new_members =
          if Enum.member?(state.room_member_cache[room_name] || [], userid) do
            SpringOut.reply(:remove_user_from_room, {userid, room_name}, nil, state)
            state.room_member_cache[room_name] |> Enum.filter(fn m -> m != userid end)
          else
            state.room_member_cache[room_name] || []
          end

        new_cache = Map.put(state.room_member_cache, room_name, new_members)
        %{state | room_member_cache: new_cache}
    end
  end

  # Actions
  defp do_action(action_type, data, state) do
    case action_type do
      :ring ->
        SpringOut.reply(:ring, {data, state.userid}, nil, state)

      :welcome ->
        SpringOut.reply(:welcome, nil, nil, state)

      :login_end ->
        SpringOut.reply(:login_end, nil, nil, state)

      _ ->
        Logger.error("No handler in tcp_server:do_action with action #{action_type}")
    end

    state
  end

  @spec flood_protect?(String.t(), map()) :: {boolean, map()}
  defp flood_protect?(_, %{exempt_from_cmd_throttle: true} = state), do: {false, state}

  defp flood_protect?("c.auth.login_queue_heartbeat" <> _, state), do: {false, state}

  defp flood_protect?(data, state) do
    cmd_timestamps =
      if String.contains?(data, "\n") do
        now = System.system_time(:second)
        limiter = now - state.flood_rate_window_size

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

  @spec engage_flood_protection(map()) :: {:stop, String.t(), map()}
  defp engage_flood_protection(state) do
    SpringOut.reply(:disconnect, "Flood protection", nil, state)
    CacheUser.set_flood_level(state.userid, 10)
    Client.disconnect(state.userid, "SpringTCPServer.flood_protection")

    {:stop, :normal, %{state | userid: nil}}
  end

  # @spec introduce_user(T.client() | T.userid() | nil, map()) :: map()
  # defp introduce_user(nil, state), do: state

  # defp introduce_user(userid, state) when is_integer(userid) do
  #   client = Client.get_client_by_id(userid)
  #   forget_user(client, state)
  # end

  # defp introduce_user(client, state) do
  #   SpringOut.reply(:user_logged_in, client, nil, state)
  #   new_known = Map.put(state.known_users, client.userid, _blank_user(client.userid))
  #   %{state | known_users: new_known}
  # end

  # @spec forget_user(T.client() | T.userid() | nil, map()) :: map()
  # defp forget_user(nil, state), do: state

  # defp forget_user(userid, state) when is_integer(userid) do
  #   client = Client.get_client_by_id(userid)
  #   forget_user(client, state)
  # end

  # defp forget_user(client, state) do
  #   case state.known_users[client.userid] do
  #     nil ->
  #       state

  #     _ ->
  #       SpringOut.reply(:user_logged_out, {client.userid, client.name}, nil, state)
  #       new_known = Map.delete(state.known_users, client.userid)
  #       %{state | known_users: new_known}
  #   end
  # end

  # Example of how gen-smtp handles upgrading the connection
  # https://github.com/gen-smtp/gen_smtp/blob/master/src/gen_smtp_server_session.erl#L683-L720
  @spec upgrade_connection(map()) :: map()
  def upgrade_connection(state) do
    :ok = state.transport.setopts(state.socket, [{:active, false}])

    ssl_opts =
      get_ssl_opts() ++
        [
          {:packet, :line},
          {:mode, :list},
          {:verify, :verify_none},
          {:ssl_imp, :new}
        ]

    case :ranch_ssl.handshake(state.socket, ssl_opts, 5000) do
      {:ok, new_socket} ->
        :ok = :ranch_ssl.setopts(new_socket, [{:active, true}])
        %{state | socket: new_socket, transport: :ranch_ssl}

      err ->
        Logger.error(
          "Error upgrading connection\nError: #{Kernel.inspect(err)}\nssl_opts: #{Kernel.inspect(ssl_opts)}"
        )

        state
    end
  end

  # Other functions
  def _blank_user(_userid, defaults \\ %{}) do
    Map.merge(
      %{
        lobby_id: nil
      },
      defaults
    )
  end
end
