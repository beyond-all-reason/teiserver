defmodule Teiserver.Agents.BattlehostAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle

  @tick_period 5000
  @leave_chance 0.5

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "BattlehostAgentServer_#{state.number}",
      email: "BattlehostAgentServer_#{state.number}@agent_email",
      extra_data: %{}
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    battle = Battle.get_battle(state.battle_id)

    new_state = cond do
      battle == nil ->
        open_battle(state)

      battle.player_count == 0 and battle.spectator_count == 0 ->
        if :rand.uniform() <= @leave_chance do
          leave_battle(state)
        else
          state
        end
    end

    {:noreply, new_state}
  end

  defp open_battle(state) do
    cmd = %{
      battle: %{
        cmd: "c.battles.create",
        name: "EU 01 - 123",
        nattype: "none",
        password: "password2",
        port: 1234,
        game_hash: "string_of_characters",
        map_hash: "string_of_characters",
        map_name: "koom valley",
        game_name: "BAR",
        engine_name: "spring-105",
        engine_version: "105.1.2.3",
        settings: %{
          max_players: 12
        }
      }
    }
    AgentLib._send(state.socket, cmd)
    reply = AgentLib._recv(state.socket)
    AgentLib.post_agent_update(state.id, "opened battle")
    %{state | battle_id: reply["battle_id"]}
  end

  defp leave_battle(state) do
    AgentLib._send(state.socket, %{cmd: "c.battles.leave_battle"})
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
