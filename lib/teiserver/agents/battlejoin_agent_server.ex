defmodule Teiserver.Agents.BattlejoinAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle

  @tick_period 7000
  @leave_chance 0.5

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "BattlejoinAgentServer_#{state.number}",
      email: "BattlejoinAgentServer_#{state.number}@agent_email",
      extra_data: %{}
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    new_state = case state.battle_id do
      nil ->
        join_battle(state)

      _ ->
        if :rand.uniform() <= @leave_chance do
          leave_battle(state)
        else
          state
        end
    end

    {:noreply, new_state}
  end

  defp join_battle(state) do
    battle_id = Battle.list_battle_ids()
      |> Enum.random()

    cmd = %{
      cmd: "c.battle.join",
      battle_id: battle_id
    }
    AgentLib._send(state.socket, cmd)
    reply = AgentLib._recv(state.socket)

    inspect(reply)

    AgentLib.post_agent_update(state.id, "opened battle")
    %{state | battle_id: battle_id}
  end

  defp leave_battle(state) do
    AgentLib._send(state.socket, %{cmd: "c.battle.leave"})
    _success = AgentLib._recv(state.socket)

    AgentLib.post_agent_update(state.id, "left battle")
    %{state | battle_id: nil}
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
       battle_id: nil,
       socket: nil
     }}
  end
end
