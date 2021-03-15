# Stated with this
# https://blog.oestrich.org/2017/07/using-ranch-with-elixir/
defmodule Teiserver.TcpServer do
  @moduledoc false
  use GenServer
  require Logger

  alias Teiserver.Client
  alias Teiserver.User
  alias Teiserver.Protocols.SpringIn
  alias Teiserver.Protocols.SpringOut
  @heartbeat 30_000
  @timeout 30

  @behaviour :ranch_protocol
  @default_protocol_in SpringIn
  @default_protocol_out SpringOut

  _ = """
  -- Testing locally
  telnet localhost 8200
  openssl s_client -connect localhost:8201

  -- Testing on website
  telnet bar.teifion.co.uk 8200
  openssl s_client -connect bar.teifion.co.uk:8201
  """

  def format_log(s) do
    s
    |> String.replace("\n", "\\n")
    |> String.replace("\t", "~~")
  end

  # Called at startup
  def start_link(opts) do
    mode = if opts[:ssl], do: :ranch_ssl, else: :ranch_tcp

    # start_listener(Ref, Transport, TransOpts0, Protocol, ProtoOpts)
    if mode == :ranch_ssl do
      {certfile, cacertfile, keyfile} = {
        Application.get_env(:central, Teiserver)[:certs][:certfile],
        Application.get_env(:central, Teiserver)[:certs][:cacertfile],
        Application.get_env(:central, Teiserver)[:certs][:keyfile]
      }

      :ranch.start_listener(
        make_ref(),
        :ranch_ssl,
        [
          {:port, Application.get_env(:central, Teiserver)[:ports][:tls]},
          {:certfile, certfile},
          {:cacertfile, cacertfile},
          {:keyfile, keyfile}
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

    :timer.send_interval(@heartbeat, self(), :heartbeat)
    state = %{
      # Connection state
      message_part: "",
      last_msg: System.system_time(:second),
      socket: socket,
      transport: transport,
      protocol_in: @default_protocol_in,
      protocol_out: @default_protocol_out,
      msg_id: nil,
      ip: ip,

      # Client state
      userid: nil,
      username: nil,
      battle_host: false,
      user: nil,

      # Connection microstate
      battle_id: nil,
      known_users: %{}
    }

    Logger.info("New TCP connection #{Kernel.inspect(socket)}, IP: #{ip}")

    send(self(), {:msg, :welcome})
    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_cast({:put, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  # If Ctrl + C is sent through it kills the connection, makes telnet debugging easier
  def handle_info({_, _socket, <<255, 244, 255, 253, 6>>}, state) do
    new_state = state.protocol.handle("EXIT", state)
    {:noreply, new_state}
  end

  # Main source of data ingress
  def handle_info({:tcp, _socket, data}, state) do
    data_in(data, state)
  end

  def handle_info({:ssl, _socket, data}, state) do
    data_in(data, state)
  end

  # Heartbeat allows us to kill stale connections
  def handle_info(:heartbeat, state) do
    diff = System.system_time(:second) - state.last_msg
    if diff > @timeout do
      {:stop, :normal, state}
    else
      {:noreply, state}
    end
  end

  # Client updates
  def handle_info({:user_logged_in, userid}, state) do
    new_state = user_logged_in(userid, state)
    {:noreply, new_state}
  end

  # Some logic because if we're the one logged out we need to disconnect
  def handle_info({:user_logged_out, userid}, state) do
    if state.userid == userid do
      {:stop, :normal, state}
    else
      new_state = user_logged_out(userid, state)
      {:noreply, new_state}
    end
  end

  def handle_info({:updated_client, new_client, reason}, state) do
    new_state = case reason do
      :client_updated_status ->
        client_status_update(new_client, state)

      :client_updated_battlestatus ->
        client_battlestatus_update(new_client, state)
    end

    {:noreply, new_state}
  end

  # Commands
  def handle_info({:ring, ringer}, state) do
    new_state = do_action(:ring, ringer, state)
    {:noreply, new_state}
  end

  # User
  def handle_info({:this_user_updated, fields}, state) do
    new_state = user_updated(fields, state)
    {:noreply, new_state}
  end


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
  def handle_info({:battle_updated, _battle_id, data, reason}, state) do
    new_state = battle_update(data, reason, state)
    {:noreply, new_state}
  end

  def handle_info({:global_battle_updated, battle_id, reason}, state) do
    new_state = global_battle_update(battle_id, reason, state)
    {:noreply, new_state}
  end

  def handle_info({:add_user_to_battle, userid, battle_id}, state) do
    new_state = user_join_battle(userid, battle_id, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_battle, userid, battle_id}, state) do
    new_state = user_leave_battle(userid, battle_id, state)
    {:noreply, new_state}
  end

  def handle_info({:kick_user_from_battle, userid, battle_id}, state) do
    new_state = user_kicked_from_battle(userid, battle_id, state)
    {:noreply, new_state}
  end

  # Connection
  def handle_info({:tcp_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.info("Closing TCP connection #{Kernel.inspect(socket)}")
    transport.close(socket)
    Client.disconnect(state.userid)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("Closing TCP connection - no transport #{Kernel.inspect(socket)}")
    Client.disconnect(state.userid)
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.debug("Closing SSL connection #{Kernel.inspect(socket)}")
    transport.close(socket)
    Client.disconnect(state.userid)
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, socket}, state) do
    Logger.debug("Closing SSL connection - no transport #{Kernel.inspect(socket)}")
    Client.disconnect(state.userid)
    {:stop, :normal, state}
  end

  def handle_info(:terminate, state) do
    Logger.info("Terminate connection #{Kernel.inspect(state.socket)}")
    Client.disconnect(state.userid)
    {:stop, :normal, state}
  end

  # def handle_info(other, state) do
  #   Logger.error("No handler: #{other}")
  #   {:noreply, state}
  # end

  def terminate(reason, state) do
    Logger.debug("disconnect because #{Kernel.inspect(reason)}")
    Client.disconnect(state.userid)
  end

  # #############################
  # Internal functions
  # #############################
  defp data_in(data, state) do
    Logger.debug("<-- #{Kernel.inspect(state.socket)} #{format_log(data)}")

    new_state =
      if String.ends_with?(data, "\n") do
        data = state.message_part <> data

        data
        |> String.split("\n")
        |> Enum.reduce(state, fn data, acc ->
          state.protocol.handle(data, acc)
        end)
        |> Map.put(:message_part, "")
      else
        %{state | message_part: state.message_part <> data}
      end

    new_state
  end

  # User updates
  defp user_logged_in(userid, state) do
    known_users = case Enum.member?(userid, state.known_users) do
      false ->
        state.protocol_out.reply(:user_logged_in, userid, state)
        Map.put(state.known_users, userid, _blank_user(userid))
      true ->
        state.known_users
    end
    %{state | known_users: known_users}
  end

  defp user_logged_out(userid, state) do
    known_users = case Enum.member?(userid, state.known_users) do
      true ->
        state.protocol_out.reply(:user_logged_out, userid, state)
        Map.put(state.known_users, userid, _blank_user(userid))
      false ->
        state.known_users
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
          state.protocol_out.reply(:friendlist, new_user, state)
        :friend_requests ->
          state.protocol_out.reply(:friendlist_request, new_user, state)
        :ignored ->
          state.protocol_out.reply(:ignorelist, new_user, state)
        _ ->
          Logger.error("No handler in tcp_server:user_updated with field #{field}")
      end
    end)
    new_state
  end

  # Client updates
  defp client_status_update(new_client, state) do
    state.protocol_out.reply(:client_status, new_client, state)
    state
  end

  defp client_battlestatus_update(new_client, state) do
    if state.battle_id != nil and state.battle_id == new_client.battle_id do
      state.protocol_out.reply(:client_battlestatus, new_client, state)
    end
    state
  end

  # Battle updates
  defp battle_update(data, reason, state) do
    case reason do
      :add_start_rectangle ->
        state.protocol_out.reply(:add_start_rectangle, data, state)

      :remove_start_rectangle ->
        state.protocol_out.reply(:remove_start_rectangle, data, state)

      :add_script_tags ->
        state.protocol_out.reply(:add_script_tags, data, state)

      :remove_script_tags ->
        state.protocol_out.reply(:remove_script_tags, data, state)

      :enable_all_units ->
        state.protocol_out.reply(:enable_all_units, data, state)

      :enable_units ->
        state.protocol_out.reply(:enable_units, data, state)

      :disable_units ->
        state.protocol_out.reply(:disable_units, data, state)

      :say ->
        state.protocol_out.reply(:battle_message, data, state)

      :sayex ->
        state.protocol_out.reply(:battle_message_ex, data, state)

      # TODO: Check we can't get an out of sync server-client state
      # with the bot commands
      :add_bot_to_battle ->
        state.protocol_out.reply(:add_bot_to_battle, data, state)

      :update_bot ->
        state.protocol_out.reply(:update_bot, data, state)

      :remove_bot ->
        state.protocol_out.reply(:remove_bot_from_battle, data, state)

      _ ->
        Logger.error("No handler in tcp_server:battle_update with reason #{reason}")
    end
    state
  end

  defp global_battle_update(battle_id, reason, state) do
    if state.battle_id == battle_id do
      case reason do
        :update_battle_info ->
          state.protocol_out.reply(:update_battle, battle_id, state)

        :battle_opened ->
          state.protocol_out.reply(:battle_opened, battle_id, state)

        :battle_closed ->
          state.protocol_out.reply(:battle_closed, battle_id, state)

        _ ->
          Logger.error("No handler in tcp_server:global_battle_update with reason #{reason}")
      end
    end
    state
  end

  # Depending on our current understanding of where the user is
  # we will send a selection of commands on the assumption this
  # genserver is incorrect and needs to alter its state accordingly
  defp user_join_battle(userid, battle_id, state) do
    new_user = cond do
      state.known_users[userid] == nil ->
        state.protocol_out.reply(:user_logged_in, userid, state)
        state.protocol_out.reply(:add_user_to_battle, {userid, battle_id}, state)
        _blank_user(userid, %{battle_id: battle_id})

      state.known_users[userid].battle_id == nil ->
        state.protocol_out.reply(:add_user_to_battle, {userid, battle_id}, state)
        %{state.known_users[userid] | battle_id: battle_id}

      state.known_users[userid].battle_id != battle_id ->
        state.protocol_out.reply(:remove_user_from_battle, {userid, battle_id}, state)
        state.protocol_out.reply(:add_user_to_battle, {userid, battle_id}, state)
        %{state.known_users[userid] | battle_id: battle_id}

      state.known_users[userid].battle_id == battle_id ->
        # No change
        state.known_users[userid]
    end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_leave_battle(userid, _battle_id, state) do
    new_user = cond do
      state.known_users[userid] == nil ->
        state.protocol_out.reply(:user_logged_in, userid, state)
        _blank_user(userid)

      state.known_users[userid].battle_id == nil ->
        # No change
        state.known_users[userid]

      true ->
        # We don't care which battle we thought they are in, they're no longer in it
        state.protocol_out.reply(:remove_user_from_battle, {userid, state.known_users[userid].battle_id}, state)
        %{state.known_users[userid] | battle_id: nil}
    end

    new_knowns = Map.put(state.known_users, userid, new_user)
    %{state | known_users: new_knowns}
  end

  defp user_kicked_from_battle(userid, battle_id, state) do
    if state.battle_host do
      cond do
        state.known_users[userid] == nil ->
          state.protocol_out.reply(:user_logged_in, userid, state)
          _blank_user(userid)

        state.known_users[userid].battle_id == nil ->
          # No change
          state.known_users[userid]

        true ->
          # We don't care which battle we thought they are in, they're no longer in it
          state.protocol_out.reply(:kick_user_from_battle, {userid, state.known_users[userid].battle_id}, state)
          %{state.known_users[userid] | battle_id: nil}
      end
    else
      user_leave_battle(userid, battle_id, state)
    end
  end

  # Chat
  defp new_chat_message(type, from, room_name, msg, state) do
    case type do
      :direct_message ->
        state.protocol_out.reply(:direct_message, {from, msg, state.user}, state)
      :chat_message ->
        state.protocol_out.reply(:chat_message, {from, room_name, msg, state.user}, state)
      :chat_message_ex ->
        state.protocol_out.reply(:chat_message_ex, {from, room_name, msg, state.user}, state)
    end
    state
  end

  defp user_join_chat_room(userid, room_name, state) do
    state.protocol_out.reply(:add_user_to_room, {userid, room_name}, state)
    state
  end

  defp user_leave_chat_room(userid, room_name, state) do
    state.protocol_out.reply(:remove_user_from_room, {userid, room_name}, state)
    state
  end

  # Actions
  defp do_action(action, data, state) do
    case action do
      :ring ->
        state.protocol_out.reply(:ring, {data, state.userid}, state)

        _ ->
          Logger.error("No handler in tcp_server:do_action with action #{action}")
    end
    state
  end

  # Other functions
  defp _blank_user(userid, defaults \\ %{}) do
    Map.merge(%{
      userid: userid,
      battle_id: nil
    }, defaults)
  end
end
