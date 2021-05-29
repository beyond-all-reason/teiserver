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
    AgentLib.post_agent_update(state.id, "idle pinged")
    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = data
    |> AgentLib.translate
    |> Enum.reduce(state, fn data, acc ->
      handle_msg(data, acc)
    end)

    {:noreply, new_state}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.system.pong"}, state) do
    state
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
