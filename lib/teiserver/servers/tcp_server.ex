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

  # Called at startup
  def start_link(opts) do
    mode = if opts[:ssl], do: :ranch_ssl, else: :ranch_tcp

    # start_listener(Ref, Transport, TransOpts0, Protocol, ProtoOpts)
    if mode == :ranch_ssl do
      {certfile, cacertfile, keyfile} = 
        {
          Application.get_env(:central, Teiserver)[:certs][:certfile],
          Application.get_env(:central, Teiserver)[:certs][:cacertfile],
          Application.get_env(:central, Teiserver)[:certs][:keyfile],
        }

      :ranch.start_listener(
        make_ref(),
        :ranch_ssl,
        [
          {:port, Application.get_env(:central, Teiserver)[:ports][:tls]},
          {:certfile, certfile},
          {:cacertfile, cacertfile},
          {:keyfile, keyfile},
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
    Logger.debug("New TCP connection")
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}])

    @default_protocol.welcome(socket, transport)

    :gen_server.enter_loop(__MODULE__, [], %{
      userid: nil,
      name: nil,
      client: nil,
      user: nil,
      socket: socket,
      msg_id: nil,
      transport: transport,
      protocol: @default_protocol
    })
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

  def handle_info({:tcp, _socket, data}, state) do
    Logger.info("<-- TCP #{String.trim(data)}")

    new_state =
      data
      |> String.split("\n")
      |> Enum.reduce(state, fn data, acc ->
        state.protocol.handle(data, acc)
      end)

    {:noreply, new_state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    Logger.info("<-- SSL #{String.trim(data)}")

    new_state =
      data
      |> String.split("\n")
      |> Enum.reduce(state, fn data, acc ->
        state.protocol.handle(data, acc)
      end)

    {:noreply, new_state}
  end

  # Client updates
  def handle_info({:logged_in_client, userid, username}, state) do
    new_state = state.protocol.reply(:logged_in_client, {userid, username}, state)
    {:noreply, new_state}
  end

  def handle_info({:logged_out_client, userid, username}, state) do
    new_state = state.protocol.reply(:logged_out_client, {userid, username}, state)
    {:noreply, new_state}
  end

  def handle_info({:updated_client, new_client, :client_updated_status}, state) do
    state.protocol.reply(:client_status, new_client, state)
    {:noreply, state}
  end

  def handle_info({:updated_client, new_client, :client_updated_battlestatus}, state) do
    state.protocol.reply(:client_battlestatus, new_client, state)
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

  def handle_info({:new_battlestatus, userid, battlestatus, team_colour}, state) do
    new_state =
      state.protocol.reply(:client_battlestatus, {userid, battlestatus, team_colour}, state)

    {:noreply, new_state}
  end

  def handle_info({:battle_updated, battle_id, data, reason}, state) do
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
      end
    end
    {:noreply, state}
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

  def handle_info({:add_user_to_battle, userid, battle_id}, state) do
    new_state = state.protocol.reply(:add_user_to_battle, {userid, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_battle, userid, battle_id}, state) do
    new_state = state.protocol.reply(:remove_user_from_battle, {userid, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:kick_user_from_battle, userid, battle_id}, state) do
    if userid == state.userid and battle_id == state.client.battle_id do
      state.protocol.reply(:forcequit_battle, state)
    end
    new_state = state.protocol.reply(:remove_user_from_battle, {userid, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:battle_message, userid, msg, battle_id}, state) do
    new_state = state.protocol.reply(:battle_message, {userid, msg, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:add_bot_to_battle, battleid, bot}, state) do
    new_state = state.protocol.reply(:add_bot_to_battle, {battleid, bot}, state)
    {:noreply, new_state}
  end

  def handle_info({:update_bot, battleid, bot}, state) do
    new_state = state.protocol.reply(:update_bot, {battleid, bot}, state)
    {:noreply, new_state}
  end

  # Connection
  def handle_info({:tcp_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.debug("Closing TCP connection")
    transport.close(socket)
    {:stop, :normal, state}
  end

  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug("Closing TCP connection - no transport")
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, socket}, %{socket: socket, transport: transport} = state) do
    Logger.debug("Closing SSL connection")
    transport.close(socket)
    {:stop, :normal, state}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    Logger.debug("Closing SSL connection - no transport")
    {:stop, :normal, state}
  end

  def handle_info(:terminate, state) do
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
