defmodule Teiserver.Agents.IdleAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib

  @tick_period 20000

  def handle_info(:startup, state) do
    AgentLib.post_agent_update(state.id, "idle startup")

    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "IdleAgentServer_#{state.number}",
      email: "IdleAgentServer_#{state.number}@agent_email",
      extra_data: %{}
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    AgentLib._send(state.socket, %{cmd: "c.system.ping"})
    _pong = AgentLib._recv(state.socket)
    AgentLib.post_agent_update(state.id, "idle pinged")
    {:noreply, state}
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts[:data], opts)
  end

  def init(opts) do
    send(self(), :startup)

    {:ok,
     %{
       id: opts.id,
       number: opts.number,
       socket: nil
     }}
  end
end
