# Stated with this
# https://blog.oestrich.org/2017/07/using-ranch-with-elixir/
defmodule Teiserver.TcpServer do
  use GenServer
  require Logger

  alias Teiserver.Protocols.Spring

  @behaviour :ranch_protocol
  @default_protocol Spring

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

    :gen_server.enter_loop(__MODULE__, [], %{
      client: nil,
      user: nil,
      socket: socket,
      transport: transport,
      protocol: @default_protocol
    })
  end

  def init(init_arg) do
    IO.puts "init"
    IO.inspect init_arg
    IO.puts ""
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
    new_state = state.protocol.handle(data, state)
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

  def handle_info(other, state) do
    IO.puts "Other, no handler"
    IO.inspect other
    IO.puts ""
    
    {:noreply, state}
  end
end