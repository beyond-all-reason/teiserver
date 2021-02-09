defmodule UDPServer.State do
  @doc ~S"""
  UDPServer State:
  port :: integer
  count :: integer
  handler :: function
  socket :: %Socket
  """
  defstruct port: nil, ip: {nil,nil,nil,nil} ,handler: {nil, nil}, socket: nil, count: 0
  @type t :: %__MODULE__{port: integer, ip: tuple, handler: tuple, socket: reference, count: integer}
end

defmodule UDPServer.Response do
  @doc ~S"""
  Struct for UDP response packet
  ip :: String.t
  fromport :: integer
  packet :: String.t
  """
  defstruct ip: nil, fromport: nil, packet: nil
  @type t :: %__MODULE__{ip: String.t, fromport: integer, packet: String.t}
end

defmodule UDPServer do
  use GenServer
  alias UDPServer.State
  alias UDPServer.Response

  def start_link(_) do
    {mod, fun} = Application.get_env :udp_server, :udp_handler, {__MODULE__, :default_handler}
    {ip, port} = {Application.get_env(:udp_server, :ip, {127, 0, 0, 1}), Application.get_env(:udp_server, :port, 8202)}
    GenServer.start_link(__MODULE__, [%State{handler: {mod, fun}, ip: ip, port: port}], name: __MODULE__)
  end

  def init([%State{} = state]) do
    require Logger
    {:ok, socket} = :gen_udp.open(state.port, [:binary, :inet,
                                               {:ip, state.ip},
                                               {:active, true}])
    {:ok, port} = :inet.port(socket)
    Logger.info("udp listening on port #{port}")
    #update state
    {:ok, %{state | socket: socket, port: port}}
  end

  def terminate(_reason, %State{socket: socket} = state) when socket != nil do
    require Logger
    Logger.info("closing port #{state.port}")
    :ok = :gen_udp.close(socket)
  end

  def count(pid) do
    GenServer.call(pid, :count)
  end

  def handle_call(:count, _from, state) do
    IO.puts "UDP call"
    
    {:reply, state.count, state}
  end

  def handle_info({:udp, socket, ip, fromport, packet}, %State{socket: socket, handler: {mod, fun}} = state) do
    IO.puts "UDP info"
    
    new_count = state.count + 1
    apply mod, fun, [%Response{ip: format_ip(ip), fromport: fromport, packet: String.trim(packet)}]
    {:noreply, %State{state | count: new_count}}
  end

  def default_handler(%Response{} = response) do
    require Logger
    Logger.info("#{response.ip}:#{response.fromport} sent: #{response.packet}")
  end

  #ip is passed as a tuple one int each octet {127,0,0,1}
  defp format_ip ({a, b, c, d}) do
    "#{a}.#{b}.#{c}.#{d}"
  end
end