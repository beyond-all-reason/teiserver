defmodule Teiserver.Agents.FrienderAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  # require Logger

  @tick_period 5_000

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "Friender_#{state.name}",
      email: "Friender_#{state.name}@agents"
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
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
       name: Map.get(opts, :name, opts.number),
       lobby_id: nil,
       socket: nil
     }}
  end
end
