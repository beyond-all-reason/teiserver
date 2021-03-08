# Stated with this
# https://blog.oestrich.org/2017/07/using-ranch-with-elixir/
defmodule Teiserver.TcpServer do
  @moduledoc false
  use GenServer
  require Logger

  alias Teiserver.Client
  alias Teiserver.User
  alias Teiserver.Protocols.SpringProtocol

  @behaviour :ranch_protocol
  @default_protocol SpringProtocol

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

    Logger.info("New connection attempt #{Kernel.inspect(socket)}, IP: #{ip}")
    x = :ranch.accept_ack(ref)
    Logger.info(":ranch.accept_ack = #{Kernel.inspect(x)} for #{Kernel.inspect(socket)}")
    y = transport.setopts(socket, [{:active, true}])
    Logger.info("transport.setopts = #{Kernel.inspect(y)} for #{Kernel.inspect(socket)}")

    state = %{
      message_part: "",
      userid: nil,
      name: nil,
      client: nil,
      user: nil,
      msg_id: nil,
      ip: ip,
      socket: socket,
      transport: transport,
      protocol: @default_protocol
    }

    state = @default_protocol.reply(:welcome, nil, state)

    Logger.info("New TCP connection #{Kernel.inspect(socket)}, IP: #{ip}")

    :gen_server.enter_loop(__MODULE__, [], state)
  end

  def init(init_arg) do
    {:ok, init_arg}
  end

  def handle_call(:get_state, _from, state) do
    {:reply, state, state}
  end

  def handle_cast({:put, key, value}, _from, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_info({_, _socket, <<255, 244, 255, 253, 6>>}, state) do
    new_state = state.protocol.handle("EXIT", state)
    {:noreply, new_state}
  end

  def handle_info({:tcp, _socket, data}, state) do
    Logger.info("<-- #{Kernel.inspect(state.socket)} #{format_log(data)}")

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

    {:noreply, new_state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    Logger.info("<-- #{Kernel.inspect(state.socket)} #{format_log(data)}")

    new_state =
      if String.ends_with?(data, "\n") do
        data
        |> String.split("\n")
        |> Enum.reduce(state, fn data, acc ->
          state.protocol.handle(data, acc)
        end)
        |> Map.put(:message_part, "")
      else
        %{state | message_part: state.message_part <> data}
      end

    {:noreply, new_state}
  end

  # Client updates
  def handle_info({:logged_in_client, userid, username}, state) do
    new_state = state.protocol.reply(:logged_in_client, {userid, username}, state)
    {:noreply, new_state}
  end

  def handle_info({:logged_out_client, userid, username}, state) do
    if state.userid == userid do
      {:stop, :normal, state}
    else
      new_state = state.protocol.reply(:logged_out_client, {userid, username}, state)
      {:noreply, new_state}
    end
  end

  def handle_info({:updated_client, new_client, :client_updated_status}, state) do
    new_state = state.protocol.reply(:client_status, new_client, state)
    {:noreply, new_state}
  end

  def handle_info({:updated_client, new_client, :client_updated_battlestatus}, state) do
    if state.client.battle_id != nil and state.client.battle_id == new_client.battle_id do
      state.protocol.reply(:client_battlestatus, new_client, state)
    end

    {:noreply, state}
  end

  def handle_info({:updated_client, new_client, _reason}, state) do
    state.protocol.reply(:client_status, new_client, state)

    new_state =
      if state.userid == new_client.userid do
        Map.put(state, :client, new_client)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info({:battle_updated, battle_id, data, reason}, state) do
    new_state =
      if state.client.battle_id == battle_id do
        case reason do
          :add_start_rectangle ->
            state.protocol.reply(:add_start_rectangle, data, state)

          :remove_start_rectangle ->
            state.protocol.reply(:remove_start_rectangle, data, state)

          :add_script_tags ->
            state.protocol.reply(:add_script_tags, data, state)

          :remove_script_tags ->
            state.protocol.reply(:remove_script_tags, data, state)

          :enable_all_units ->
            state.protocol.reply(:enable_all_units, data, state)

          :enable_units ->
            state.protocol.reply(:enable_units, data, state)

          :disable_units ->
            state.protocol.reply(:disable_units, data, state)

          _ ->
            Logger.error("No handler in tcp_server:battle_updated with reason #{reason}")
        end
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info({:all_battle_updated, battle_id, reason}, state) do
    new_state =
      case reason do
        :update_battle_info ->
          state.protocol.reply(:update_battle, battle_id, state)

        _ ->
          Logger.error("No handler in tcp_server:all_battle_updated with reason #{reason}")
      end

    {:noreply, new_state}
  end

  # Commands
  def handle_info({:ring, ringer}, state) do
    new_state = state.protocol.reply(:ring, {ringer, state.user}, state)
    {:noreply, new_state}
  end

  # User
  def handle_info({:this_user_updated, fields}, state) do
    new_user = User.get_user_by_id(state.userid)
    new_state = %{state | user: new_user}

    fields
    |> Enum.each(fn field ->
      case field do
        :friends -> state.protocol.reply(:friendlist, new_user, state)
        :friend_requests -> state.protocol.reply(:friendlist_request, new_user, state)
        :ignored -> state.protocol.reply(:ignorelist, new_user, state)
      end
    end)

    {:noreply, new_state}
  end

  # Chat
  def handle_info({:direct_message, from, msg}, state) do
    new_state = state.protocol.reply(:direct_message, {from, msg, state.user}, state)
    {:noreply, new_state}
  end

  def handle_info({:new_message, from, room_name, msg}, state) do
    new_state = state.protocol.reply(:chat_message, {from, room_name, msg, state.user}, state)
    {:noreply, new_state}
  end

  def handle_info({:new_message_ex, from, room_name, msg}, state) do
    new_state = state.protocol.reply(:chat_message_ex, {from, room_name, msg, state.user}, state)
    {:noreply, new_state}
  end

  def handle_info({:add_user_to_room, userid, room_name}, state) do
    new_state = state.protocol.reply(:add_user_to_room, {userid, room_name}, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_room, userid, room_name}, state) do
    new_state = state.protocol.reply(:remove_user_from_room, {userid, room_name}, state)
    {:noreply, new_state}
  end

  # Battles
  def handle_info({:battle_opened, battle_id}, state) do
    new_state = state.protocol.reply(:battle_opened, battle_id, state)
    {:noreply, new_state}
  end

  def handle_info({:battle_closed, battle_id}, state) do
    new_state = state.protocol.reply(:battle_closed, battle_id, state)
    {:noreply, new_state}
  end

  def handle_info({:add_user_to_battle, userid, battle_id}, state) do
    new_state =
      if userid != state.userid do
        state.protocol.reply(:add_user_to_battle, {userid, battle_id}, state)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_battle, userid, battle_id}, state) do
    new_state = state.protocol.reply(:remove_user_from_battle, {userid, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:kick_user_from_battle, userid, battle_id}, state) do
    if userid == state.userid and battle_id == state.client.battle_id do
      state.protocol.reply(:forcequit_battle, nil, state)
    end

    new_state = state.protocol.reply(:remove_user_from_battle, {userid, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:battle_message, userid, msg, battle_id}, state) do
    new_state = state.protocol.reply(:battle_message, {userid, msg, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:battle_message_ex, userid, msg, battle_id}, state) do
    new_state = state.protocol.reply(:battle_message_ex, {userid, msg, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:add_bot_to_battle, battle_id, bot}, state) do
    new_state = state.protocol.reply(:add_bot_to_battle, {battle_id, bot}, state)
    {:noreply, new_state}
  end

  def handle_info({:update_bot, battle_id, bot}, state) do
    if state.client.battle_id == battle_id do
      state.protocol.reply(:update_bot, {battle_id, bot}, state)
    end

    {:noreply, state}
  end

  def handle_info({:remove_bot_from_battle, battle_id, botname}, state) do
    if state.client.battle_id == battle_id do
      state.protocol.reply(:remove_bot_from_battle, {battle_id, botname}, state)
    end

    {:noreply, state}
  end

  # Email
  def handle_info({:delivered_email, _email}, state) do
    {:noreply, state}
  end

  # Connection
  def handle_info({:tcp_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.info("Closing TCP connection #{Kernel.inspect(socket)}")
    transport.close(socket)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, socket}, state) do
    Logger.info("Closing TCP connection - no transport #{Kernel.inspect(socket)}")
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.debug("Closing SSL connection #{Kernel.inspect(socket)}")
    transport.close(socket)
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, socket}, state) do
    Logger.debug("Closing SSL connection - no transport #{Kernel.inspect(socket)}")
    {:stop, :normal, state}
  end

  def handle_info(:terminate, state) do
    Logger.info("Terminate connection #{Kernel.inspect(state.socket)}")
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
end
