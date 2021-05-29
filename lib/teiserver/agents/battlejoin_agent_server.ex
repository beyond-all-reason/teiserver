defmodule Teiserver.Agents.BattlejoinAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle
  require Logger

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
    new_state = case state.stage do
      :no_battle ->
        join_battle(state, Battle.list_battle_ids())

      :waiting ->
        state

      :in_battle ->
        if :rand.uniform() <= @leave_chance do
          leave_battle(state)
        else
          state
        end
    end

    {:noreply, new_state}
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
  defp handle_msg(%{"cmd" => "s.battle.join", "result" => "waiting_for_host"}, state) do
    %{state | stage: :waiting}
  end
  defp handle_msg(%{"cmd" => "s.battle.join_response", "result" => "failure"}, state) do
    %{state | stage: :no_battle, battle_id: nil}
  end
  defp handle_msg(%{"cmd" => "s.battle.join_response", "result" => "approve"}, state) do
    %{state | stage: :in_battle}
  end
  defp handle_msg(%{"cmd" => "s.battle.join_response", "result" => "reject"}, state) do
    %{state | stage: :no_battle, battle_id: nil}
  end
  defp handle_msg(%{"cmd" => "s.battle.leave", "result" => "success"}, state) do
    %{state | battle_id: nil}
  end

  defp join_battle(state, []), do: state
  defp join_battle(state, battle_ids) do
    battle_id = Enum.random(battle_ids)

    cmd = %{
      cmd: "c.battle.join",
      battle_id: battle_id,
      password: "password2"
    }
    AgentLib._send(state.socket, cmd)

    AgentLib.post_agent_update(state.id, "opened battle")
    %{state | battle_id: battle_id, stage: :waiting}
  end

  defp leave_battle(state) do
    AgentLib._send(state.socket, %{cmd: "c.battle.leave"})

    AgentLib.post_agent_update(state.id, "left battle")
    %{state | battle_id: nil, stage: :no_battle}
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
       stage: :no_battle,
       socket: nil
     }}
  end
end
