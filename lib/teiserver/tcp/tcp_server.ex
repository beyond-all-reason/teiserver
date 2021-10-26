defmodule Teiserver.TcpServer do
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
  def start_link(opts) do
    mode = if opts[:ssl], do: :ranch_ssl, else: :ranch_tcp

    # start_listener(Ref, Transport, TransOpts0, Protocol, ProtoOpts)
    if mode == :ranch_ssl do
      ssl_opts = get_ssl_opts()

      :ranch.start_listener(
        make_ref(),
        :ranch_ssl,
        ssl_opts ++
          [
            {:port, Application.get_env(:central, Teiserver)[:ports][:tls]}
          ],
        __MODULE__,
        []
      )
    else
      :ranch.start_listener(
        make_ref(),
        :ranch_tcp,
        [
          {:port, Application.get_env(:central, Teiserver)[:ports][:tcp]}
        ],
        __MODULE__,
        []
      )
    end
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
      protocol_in: Application.get_env(:central, Teiserver)[:default_protocol].protocol_in(),
      protocol_out: Application.get_env(:central, Teiserver)[:default_protocol].protocol_out(),
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
      room_member_cache: %{},
      known_users: %{},
      known_battles: [],
      extra_logging: Application.get_env(:central, Teiserver)[:extra_logging],
      script_password: nil,
      exempt_from_cmd_throttle: true,
      cmd_timestamps: []
    }

    Logger.info("New TCP connection #{Kernel.inspect(socket)}, IP: #{ip}")

    send(self(), {:action, {:welcome, nil}})
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def init(init_arg) do
    {:ok, init_arg}
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
    new_state = state.protocol_in.handle("EXIT", state)
    {:noreply, new_state}
  end

  # Main source of data ingress
  def handle_info({:tcp, _socket, data}, %{exempt_from_cmd_throttle: false} = state) do
    cmd_timestamps = if String.contains?(data, "\n") do
      now = System.system_time(:second)
      limiter = now - @cmd_flood_duration

      cmd_timestamps = [now | state.cmd_timestamps]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter end)

      if Enum.count(cmd_timestamps) > @cmd_flood_limit do
        Logger.error("Command overflow from #{state.username}/#{state.userid} with #{Enum.count(cmd_timestamps)} commands")
      end

      cmd_timestamps
    else
      state.cmd_timestamps
    end

    new_state = state.protocol_in.data_in(data, state)
    {:noreply, %{new_state | cmd_timestamps: cmd_timestamps}}
  end
  def handle_info({:tcp, _socket, data}, %{exempt_from_cmd_throttle: true} = state) do
    new_state = state.protocol_in.data_in(data, state)
    {:noreply, new_state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = state.protocol_in.data_in(data, state)
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

  def handle_info({:action, {action_type, data}}, state) do
    new_state = do_action(action_type, data, state)
    {:noreply, new_state}
  end

  # Client channel messages
  def handle_info({:client_message, :direct_message, _userid, {_from_id, _message}}, state) do
    # TODO: Currently we seem to subscribe to multiple channels at once
    # so if we uncomment this we get messages double up
    # new_state = new_chat_message(:direct_message, from_id, nil, message, state)
    # {:noreply, new_state}
    {:noreply, state}
  end

  def handle_info({:client_message, :matchmaking, _userid, data}, state) do
    {:noreply, matchmaking_update(data, state)}
  end

  def handle_info({:client_message, :lobby, userid, data}, state) do
    {:noreply, TcpLobby.handle_info({:client_message, :lobby, userid, data}, state)}
  end

  def handle_info({:global_battle_lobby, action, lobby_id}, state) do
    {:noreply, TcpLobby.handle_info({:global_battle_lobby, action, lobby_id}, state)}
  end

  def handle_info({:client_message, topic, _userid, _data}, state) do
    Logger.warn("No tcp_server handler for :client_message with topic #{topic}")
    {:noreply, state}
  end

  # teiserver_lobby_updates:#{lobby_id}

  # Client updates
  def handle_info({:user_logged_in, nil}, state), do: {:noreply, state}
  def handle_info({:user_logged_in, userid}, state) do
    new_state = user_logged_in(userid, state)
    {:noreply, new_state}
  end


  # Lobby chat
  # def handle_info({:lobby_chat, action, lobby_id, userid, msg}, state) do
  #   {:noreply, TcpChat.do_handle({action, lobby_id, userid, msg}, state)}
  # end


  # Some logic because if we're the one logged out we need to disconnect
  def handle_info({:user_logged_out, userid, username}, state) do
    if state.userid == userid do
      {:stop, :normal, state}
    else
      new_state = user_logged_out(userid, username, state)
      {:noreply, new_state}
    end
  end

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

  # Battles
  def handle_info({:battle_updated, _lobby_id, data, reason}, state) do
    new_state = battle_update(data, reason, state)
    {:noreply, new_state}
  end

  def handle_info({:global_battle_updated, lobby_id, reason}, state) do
    new_state = global_battle_update(lobby_id, reason, state)
    {:noreply, new_state}
  end

  def handle_info({:request_user_join_battle, userid}, state) do
    new_state = request_user_join_battle(userid, state)
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

  def handle_info({:add_user_to_battle, userid, lobby_id, script_password}, state) do
    new_state = user_join_battle(userid, lobby_id, script_password, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_battle, userid, lobby_id}, state) do
    new_state = user_leave_battle(userid, lobby_id, state)
    {:noreply, new_state}
  end

  def handle_info({:kick_user_from_battle, userid, lobby_id}, state) do
    new_state = user_kicked_from_battle(userid, lobby_id, state)
    {:noreply, new_state}
  end

  # Timeout error
  def handle_info({:tcp_error, _port, :etimedout}, %{socket: socket, transport: transport} = state) do
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with tcp_error :etimedout")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info({:tcp_error, _port, :ehostunreach}, %{socket: socket, transport: transport} = state) do
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with tcp_error :ehostunreach")
    {:stop, :normal, %{state | userid: nil}}
  end

  # Connection
  def handle_info({:tcp_closed, _socket}, %{socket: socket, transport: transport} = state) do
    transport.close(socket)
    Client.disconnect(state.userid, ":tcp_closed with socket")
    {:stop, :normal, %{state | userid: nil}}
  end

  def handle_info({:tcp_closed, _socket}, state) do
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
    Client.disconnect(state.userid, "tcp_server :terminate")
    {:stop, :normal, %{state | userid: nil}}
  end

  def terminate(_reason, state) do
    Client.disconnect(state.userid, "tcp_server terminate")
  end

  # #############################
  # Internal functions
  # #############################
  # User updates
  defp user_logged_in(userid, state) do
    known_users =
      case state.known_users[userid] do
        nil ->
          state.protocol_out.reply(:user_logged_in, userid, nil, state)
          Map.put(state.known_users, userid, _blank_user(userid))

        _ ->
          state.known_users
      end

    %{state | known_users: known_users}
  end

  defp user_logged_out(userid, username, state) do
    known_users =
      case state.known_users[userid] do
        nil ->
          state.known_users

        _ ->
          state.protocol_out.reply(:user_logged_out, {userid, username}, nil, state)
          Map.delete(state.known_users, userid)
      end

    %{state | known_users: known_users}
  end

  defp user_updated(fields, state) do
    new_user = User.get_user_by_id(state.userid)
    new_state = %{state | user: new_user}

    fields
    |> Enum.each(fn field ->
      case field do
        :friends ->
          state.protocol_out.reply(:friendlist, new_user, nil, state)

        :friend_requests ->
          state.protocol_out.reply(:friendlist_request, new_user, nil, state)

        :ignored ->
          state.protocol_out.reply(:ignorelist, new_user, nil, state)

        _ ->
          Logger.error("No handler in tcp_server:user_updated with field #{field}")
      end
    end)

    new_state
  end

  # Client updates
  defp client_status_update(new_client, state) do
    state.protocol_out.reply(:client_status, new_client, nil, state)
    state
  end

  defp client_battlestatus_update(new_client, state) do
    if state.lobby_id != nil and state.lobby_id == new_client.lobby_id do
      state.protocol_out.reply(:client_battlestatus, new_client, nil, state)
    end

    state
  end

  # Matchmaking
  defp matchmaking_update({cmd, data}, state) do
    case cmd do
      :match_ready ->
        state.protocol_out.reply(:matchmaking, :match_ready, data, nil, state)
        %{state | ready_queue_id: data}

      :match_cancel ->
        %{state | ready_queue_id: nil}

      :join_lobby ->
        # TODO: Make it so we know what the script password is because normally it's sent
        # by the client, maybe update the MM protocol so when you join a queue it's there?
        state.protocol_out.do_join_battle(state, data, state.script_password)

      :dequeue ->
        state
    end
  end

  # Battle updates
  defp battle_update(data, reason, state) do
    case reason do
      :add_start_rectangle ->
        state.protocol_out.reply(:add_start_rectangle, data, nil, state)

      :remove_start_rectangle ->
        state.protocol_out.reply(:remove_start_rectangle, data, nil, state)

      :add_script_tags ->
        state.protocol_out.reply(:add_script_tags, data, nil, state)

      :remove_script_tags ->
        state.protocol_out.reply(:remove_script_tags, data, nil, state)

      :enable_all_units ->
        state.protocol_out.reply(:enable_all_units, data, nil, state)

      :enable_units ->
        state.protocol_out.reply(:enable_units, data, nil, state)

      :disable_units ->
        state.protocol_out.reply(:disable_units, data, nil, state)

      :say ->
        state.protocol_out.reply(:battle_message, data, nil, state)

      :sayex ->
        state.protocol_out.reply(:battle_message_ex, data, nil, state)

      # TODO: Check we can't get an out of sync server-client state
      # with the bot commands
      :add_bot_to_battle ->
        state.protocol_out.reply(:add_bot_to_battle, data, nil, state)

      :update_bot ->
        state.protocol_out.reply(:update_bot, data, nil, state)

      :remove_bot_from_battle ->
        state.protocol_out.reply(:remove_bot_from_battle, data, nil, state)

      _ ->
        Logger.error("No handler in tcp_server:battle_update with reason #{reason}")
        state
    end
  end

  defp global_battle_update(lobby_id, reason, state) do
    case reason do
      :update_battle_info ->
        state.protocol_out.reply(:update_battle, lobby_id, nil, state)

      :battle_opened ->
        if state.lobby_host == false or state.lobby_id != lobby_id do
          new_known_battles = [lobby_id | state.known_battles]
          new_state = %{state | known_battles: new_known_battles}
          new_state.protocol_out.reply(:battle_opened, lobby_id, nil, new_state)
        else
          state
        end

      :battle_closed ->
        if Enum.member?(state.known_battles, lobby_id) do
          new_known_battles = List.delete(state.known_battles, lobby_id)
          new_state = %{state | known_battles: new_known_battles}
          new_state.protocol_out.reply(:battle_closed, lobby_id, nil, new_state)
        else
          state
        end

      _ ->
        Logger.error("No handler in tcp_server:global_battle_update with reason #{reason}")
        state
    end
  end

  # This is the server asking the host if a client can join the battle
  # the client is expected to reply with a yes or no
  defp request_user_join_battle(userid, state) do
    state.protocol_out.reply(:request_user_join_battle, userid, nil, state)
  end

  # This is the result of the host responding to the server asking if the client
  # can join the battle
  defp join_battle_request_response(nil, _, _, state) do
    state.protocol_out.reply(:join_battle_failure, "No battle", nil, state)
  end
  defp join_battle_request_response(lobby_id, response, reason, state) do
    case response do
      :accept ->
        state.protocol_out.do_join_battle(state, lobby_id, state.script_password)

      :deny ->
        state.protocol_out.reply(:join_battle_failure, reason, nil, state)
    end
  end

  # This is the result of being forced to join a battle
  defp force_join_battle(lobby_id, script_password, state) do
    new_state = state.protocol_out.do_leave_battle(state, state.lobby_id)
    new_state = %{new_state | lobby_id: lobby_id, script_password: script_password}
    state.protocol_out.do_join_battle(new_state, lobby_id, script_password)
  end

  # Depending on our current understanding of where the user is
  # we will send a selection of commands on the assumption this
  # genserver is incorrect and needs to alter its state accordingly
  defp user_join_battle(userid, lobby_id, script_password, state) do
    script_password =
      cond do
        state.lobby_host and state.lobby_id == lobby_id -> script_password
        state.userid == userid -> script_password
        true -> nil
      end

    new_user =
      cond do
        state.userid == userid ->
          _blank_user(userid, %{lobby_id: lobby_id})

        # User isn't known about so we say they've logged in
        # Then we add them to the battle
        state.known_users[userid] == nil ->
          state.protocol_out.reply(:user_logged_in, userid, nil, state)

          state.protocol_out.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          _blank_user(userid, %{lobby_id: lobby_id})

        # User is known about and not in a battle, this is the ideal
        # state
        state.known_users[userid].lobby_id == nil ->
          state.protocol_out.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: lobby_id}

        # User is known about but already in a battle
        state.known_users[userid].lobby_id != lobby_id ->
          # If we don't know about the battle we don't need to remove the user from it first
          if Enum.member?(state.known_battles, state.known_users[userid].lobby_id) do
            state.protocol_out.reply(
              :remove_user_from_battle,
              {userid, state.known_users[userid].lobby_id},
              nil,
              state
            )
          end

          state.protocol_out.reply(
            :add_user_to_battle,
            {userid, lobby_id, script_password},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: lobby_id}

        # User is known about and in this battle already, no change
        state.known_users[userid].lobby_id == lobby_id ->
          state.known_users[userid]
      end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_leave_battle(userid, lobby_id, state) do
    # If they are kicked then it's possible they won't be unsubbed
    if userid == state.userid do
      Phoenix.PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{lobby_id}")
    end

    # Do they know about the battle?
    state = if not Enum.member?(state.known_battles, lobby_id) do
      state.protocol_out.reply(:battle_opened, lobby_id, nil, state)
    else
      state
    end

    # Now the user
    new_user =
      cond do
        Enum.member?(state.known_battles, lobby_id) == false ->
          state.known_users[userid]

        state.known_users[userid] == nil ->
          state.protocol_out.reply(:user_logged_in, userid, nil, state)
          _blank_user(userid)

        state.known_users[userid].lobby_id == nil ->
          # No change
          state.known_users[userid]

        true ->
          # We don't care which battle we thought they are in, they're no longer in it
          state.protocol_out.reply(
            :remove_user_from_battle,
            {userid, state.known_users[userid].lobby_id},
            nil,
            state
          )

          %{state.known_users[userid] | lobby_id: nil}
      end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_kicked_from_battle(userid, lobby_id, state) do
    # If it's the user, we need to tell them the bad news
    state =
      if userid == state.userid do
        state.protocol_out.reply(:forcequit_battle, nil, nil, state)
        %{state | lobby_id: nil}
      else
        state
      end

    user_leave_battle(userid, lobby_id, state)
  end

  # Chat
  defp new_chat_message(type, from, room_name, msg, state) do
    case type do
      :direct_message ->
        state.protocol_out.reply(:direct_message, {from, msg, state.user}, nil, state)

      :chat_message ->
        state.protocol_out.reply(:chat_message, {from, room_name, msg, state.user}, nil, state)

      :chat_message_ex ->
        state.protocol_out.reply(:chat_message_ex, {from, room_name, msg, state.user}, nil, state)
    end

    state
  end

  defp user_join_chat_room(userid, room_name, state) do
    new_members =
      if not Enum.member?(state.room_member_cache[room_name] || [], userid) do
        state.protocol_out.reply(:add_user_to_room, {userid, room_name}, nil, state)
        [userid | (state.room_member_cache[room_name] || [])]
      else
        state.room_member_cache[room_name] || []
      end

    new_cache = Map.put(state.room_member_cache, room_name, new_members)
    %{state | room_member_cache: new_cache}
  end

  defp user_leave_chat_room(userid, room_name, state) do
    new_members =
      if Enum.member?(state.room_member_cache[room_name] || [], userid) do
        state.protocol_out.reply(:remove_user_from_room, {userid, room_name}, nil, state)
        state.room_member_cache[room_name] |> Enum.filter(fn m -> m != userid end)
      else
        state.room_member_cache[room_name] || []
      end

    new_cache = Map.put(state.room_member_cache, room_name, new_members)
    %{state | room_member_cache: new_cache}
  end

  # Actions
  defp do_action(action_type, data, state) do
    case action_type do
      :ring ->
        state.protocol_out.reply(:ring, {data, state.userid}, nil, state)

      :welcome ->
        state.protocol_out.reply(:welcome, nil, nil, state)

      :login_end ->
        state.protocol_out.reply(:login_end, nil, nil, state)

      _ ->
        Logger.error("No handler in tcp_server:do_action with action #{action_type}")
    end

    state
  end

  # Example of how gen-smtp handles upgrading the connection
  # https://github.com/gen-smtp/gen_smtp/blob/master/src/gen_smtp_server_session.erl#L683-L720
  @spec upgrade_connection(Map.t()) :: Map.t()
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
          "Error upgrading connection\nError: #{Kernel.inspect(err)}\nssl_opts: #{
            Kernel.inspect(ssl_opts)
          }"
        )

        state
    end
  end

  # Other functions
  defp _blank_user(userid, defaults \\ %{}) do
    Map.merge(
      %{
        userid: userid,
        lobby_id: nil
      },
      defaults
    )
  end
end
