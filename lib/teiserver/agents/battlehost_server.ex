defmodule Teiserver.Agents.BattlehostServer do
  use GenServer
  alias Teiserver.Agents.AgentLib

  @tick_period 5000

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "BattlehostServer_#{state.number}",
      email: "BattlehostServer_#{state.number}@agent_email",
      extra_data: %{}
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    AgentLib.post_agent_update({state.id, :tick})
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
