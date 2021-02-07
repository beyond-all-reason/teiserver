# Stated with this
# https://blog.oestrich.org/2017/07/using-ranch-with-elixir/
defmodule Teiserver.TcpServer do
  use GenServer
  require Logger
  alias Phoenix.PubSub

  alias Teiserver.Client
  alias Teiserver.User
  alias Teiserver.Protocols.SpringProtocol

  @behaviour :ranch_protocol
  @default_protocol SpringProtocol

  def start_link(_opts) do
    :ranch.start_listener(make_ref(), :ranch_tcp, [{:port, 8200}], __MODULE__, [])
  end

  def start_link(ref, socket, transport, _opts) do
    pid = :proc_lib.spawn_link(__MODULE__, :init, [ref, socket, transport])
    {:ok, pid}
  end

  def init(ref, socket, transport) do
    Logger.debug("New TCP connection")
    :ok = :ranch.accept_ack(ref)
    :ok = transport.setopts(socket, [{:active, true}])

    @default_protocol.welcome(socket, transport)

    :ok = PubSub.subscribe(Teiserver.PubSub, "battle_updates")
    :ok = PubSub.subscribe(Teiserver.PubSub, "client_updates")
    :ok = PubSub.subscribe(Teiserver.PubSub, "user_updates")
    :gen_server.enter_loop(__MODULE__, [], %{
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
    Logger.debug("<-- #{data}")
    new_state = data
    |> String.split("\n")
    |> Enum.reduce(state, fn (data, acc) ->
      state.protocol.handle(data, acc)
    end)
    {:noreply, new_state}
  end

  # Client updates
  def handle_info({:logged_in_client, username}, state) do
    new_state = state.protocol.reply(:logged_in_client, username, state)
    {:noreply, new_state}
  end

  def handle_info({:updated_client_status, username, status}, state) do
    new_state = state.protocol.reply(:new_clientstatus, [username, status], state)
    {:noreply, new_state}
  end

  def handle_info({:updated_client, new_client}, state) when is_map(new_client) do
    new_state = if state.name == new_client.name do
      Map.put(state, :client, new_client)
    else
      state
    end
    {:noreply, new_state}
  end

  def handle_info({:new_battlestatus, username, battlestatus, team_colour}, state) do
    new_state = state.protocol.reply(:battlestatus, [username, battlestatus, team_colour], state)
    {:noreply, new_state}
  end

  # User
  def handle_info({:this_user_updated, fields}, state) do
    new_user = User.get_user(state.name)
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
  def handle_info({:new_message, from, room_name, msg}, state) do
    new_state = state.protocol.reply(:chat_message, [from, room_name, msg], state)
    {:noreply, new_state}
  end

  def handle_info({:add_user_to_room, username, room_name}, state) do
    new_state = state.protocol.reply(:add_user_to_room, {username, room_name}, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_room, username, room_name}, state) do
    new_state = state.protocol.reply(:remove_user_from_room, {username, room_name}, state)
    {:noreply, new_state}
  end

  # Battles
  def handle_info({:add_user_to_battle, username, battle_id}, state) do
    new_state = state.protocol.reply(:add_user_to_battle, {username, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:remove_user_from_battle, username, battle_id}, state) do
    new_state = state.protocol.reply(:remove_user_from_battle, {username, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:battle_message, username, msg, battle_id}, state) do
    new_state = state.protocol.reply(:battle_message, {username, msg, battle_id}, state)
    {:noreply, new_state}
  end

  def handle_info({:tcp_closed, socket}, state = %{socket: socket, transport: transport}) do
    Logger.debug("Closing TCP connection")
    transport.close(socket)
    {:stop, :normal, state}
  end
  
  def handle_info({:tcp_closed, _socket}, state) do
    Logger.debug("Closing TCP connection - no transport")
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
    Logger.warn("disconnect because #{Kernel.inspect reason}")
    Client.disconnect(state.name)
  end
end