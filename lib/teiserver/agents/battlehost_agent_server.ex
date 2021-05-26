defmodule Teiserver.Agents.BattlehostAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle
  require Logger

  @read_period 500
  @tick_period 5000
  @inaction_chance 0.5
  @leave_chance 0.5

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "BattlehostAgentServer_#{state.name}",
      email: "BattlehostAgentServer_#{state.name}@agent_email",
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
    battle = Battle.get_battle(state.battle_id)

    new_state = cond do
      # Chance of doing nothing
      :rand.uniform() <= state.inaction_chance ->
        state

      battle == nil ->
        Logger.warn("#{state.name} - opening")
        open_battle(state)

      state.always_leave ->
        Logger.warn("#{state.name} - leaving anyway")
        leave_battle(state)

      battle.player_count == 0 and battle.spectator_count == 0 ->
        if :rand.uniform() <= @leave_chance do
          Logger.warn("#{state.name} - leaving empty")
          leave_battle(state)
        else
          state
        end

      # There are players in a battle, we do nothing
      true ->
        state
    end

    {:noreply, new_state}
  end

  defp do_read(state) do
    case AgentLib._recv(state.socket, 50) do
      :timeout ->
        state
      msg ->
        state = case msg do
          %{"cmd" => "s.battle.request_to_join", "userid" => userid} ->
            cmd = %{cmd: "c.battle.respond_to_join_request", userid: userid, response: "approve"}
            AgentLib._send(state.socket, cmd)
            state
          %{"cmd" => "s.battle.leave", "result" => "success"} ->
            %{state | battle_id: nil}
          msg ->
            throw "No handler for msg: #{msg}"
            state
        end
        do_read(state)
    end
  end

  defp open_battle(state) do
    cmd = %{
      cmd: "c.battle.create",
      battle: %{
        cmd: "c.battles.create",
        name: "BH #{state.name} - #{:rand.uniform(9999)}",
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
    %{state | battle_id: reply["battle"]["id"]}
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
       name: Map.get(opts, :name, opts.number),
       battle_id: nil,
       socket: nil,
       leave_chance: Map.get(opts, :leave_chance, @leave_chance),
       inaction_chance: Map.get(opts, :leave_chance, @inaction_chance),
       always_leave: Map.get(opts, :always_leave, false)
     }}
  end
end
