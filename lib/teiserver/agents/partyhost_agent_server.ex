defmodule Teiserver.Agents.PartyhostAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  # require Logger

  @tick_period 5_000

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "Partyhost_#{state.name}",
      email: "Partyhost_#{state.name}@agents"
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    if state.party_id == nil do
      AgentLib._send(state.socket, %{cmd: "c.party.create"})
    end

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
  defp handle_msg(%{"cmd" => "s.party.create", "party" => party}, state) do
    %{state | party_id: party["id"]}
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
       name: Map.get(opts, :name, opts.number),
       party_id: nil,
       socket: nil
     }}
  end
end
