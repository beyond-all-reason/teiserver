defmodule Teiserver.Agents.BattlejoinAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle
  require Logger

  @read_period 500
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
    :timer.send_interval(@read_period, self(), :read)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:read, state) do
    {:noreply, do_read(state)}
  end

  def handle_info(:tick, state) do
    new_state = case state.stage do
      :no_battle ->
        join_battle(state, Battle.list_battle_ids())

      :waiting ->
        # Logger.warn("WAITING")
        state

      :in_battle ->
        if :rand.uniform() <= @leave_chance do
          # Logger.warn("LEAVING")
          leave_battle(state)
        else
          # Logger.warn("STAYING")
          state
        end
    end

    {:noreply, new_state}
  end

  defp do_read(state) do
    case AgentLib._recv(state.socket, 50) do
      :timeout ->
        state
      msg ->
        state = case msg do
          %{"cmd" => "s.battle.join_response", "result" => "approve"} ->
            # Logger.warn("JOINED")

            %{state | stage: :in_battle}

          # This might be because the battle has closed
          %{"cmd" => "s.battle.join_response", "result" => "reject"} ->
            %{state | stage: :no_battle, battle_id: nil}

          msg ->
            throw "No handler for msg: #{msg}"
            state
        end
        do_read(state)
    end
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
    _ = AgentLib._recv(state.socket)

    AgentLib.post_agent_update(state.id, "opened battle")
    %{state | battle_id: battle_id, stage: :waiting}
  end

  defp leave_battle(state) do
    AgentLib._send(state.socket, %{cmd: "c.battle.leave"})
    _success = AgentLib._recv(state.socket)

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
