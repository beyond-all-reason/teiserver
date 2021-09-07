defmodule Teiserver.Agents.BattlehostAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Battle.Lobby
  require Logger

  @tick_period 5000
  @inaction_chance 0.5
  @leave_chance 0.5
  @password_chance 0.5

  @map_hash "1565299817"
  @game_hash "-1321904802"
  @game_name "Beyond All Reason test-17135-7661a24"
  @engine_version "104.0.1-1977-g12700e0 BAR"

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "BattlehostAgentServer_#{state.name}",
      email: "BattlehostAgentServer_#{state.name}@agent_email",
      bot: true
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    battle = Lobby.get_battle(state.lobby_id)

    new_state = cond do
      # Chance of doing nothing
      :rand.uniform() <= state.inaction_chance ->
        state

      battle == nil ->
        open_battle(state)
        state

      state.always_leave ->
        leave_battle(state)

      battle.player_count == 0 and battle.spectator_count == 0 ->
        if :rand.uniform() <= state.leave_chance do
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

  def handle_info({:ssl, _socket, data}, state) do
    new_state = data
    |> AgentLib.translate
    |> Enum.reduce(state, fn data, acc ->
      handle_msg(data, acc)
    end)

    {:noreply, new_state}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.request_to_join", "userid" => userid}, %{reject: true} = state) do
    cmd = %{cmd: "c.lobby.respond_to_join_request", userid: userid, response: "reject", reason: "because"}
    AgentLib._send(state.socket, cmd)
    state
  end
  defp handle_msg(%{"cmd" => "s.lobby.request_to_join", "userid" => userid}, %{reject: false} = state) do
    cmd = %{cmd: "c.lobby.respond_to_join_request", userid: userid, response: "approve"}
    AgentLib._send(state.socket, cmd)
    state
  end
  defp handle_msg(%{"cmd" => "s.lobby.leave", "result" => "success"}, state) do
    %{state | lobby_id: nil}
  end
  defp handle_msg(%{"cmd" => "s.lobby.create", "lobby" => %{"id" => lobby_id}}, state) do
    %{state | lobby_id: lobby_id}
  end
  defp handle_msg(%{"cmd" => "s.communication.direct_message"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.announce"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.message"}, state), do: state

  defp open_battle(state) do
    password = if :rand.uniform() <= state.password_chance, do: "password"

    cmd = %{
      cmd: "c.lobby.create",
      lobby: %{
        cmd: "c.battles.create",
        name: "BH #{state.name} - #{:rand.uniform(9999)}",
        nattype: "none",
        password: password,
        port: 1234,
        game_hash: @game_hash,
        map_hash: @map_hash,
        map_name: "Comet Catcher Remake 1.8",
        game_name: @game_name,
        engine_name: "spring",
        engine_version: @engine_version,
        settings: %{
          max_players: 12
        }
      }
    }
    AgentLib._send(state.socket, cmd)
  end

  defp leave_battle(state) do
    AgentLib._send(state.socket, %{cmd: "c.lobby.leave"})
    AgentLib.post_agent_update(state.id, "left battle")
    %{state | lobby_id: nil}
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
       lobby_id: nil,
       socket: nil,
       reject: Map.get(opts, :reject, false),
       leave_chance: Map.get(opts, :leave_chance, @leave_chance),
       inaction_chance: Map.get(opts, :leave_chance, @inaction_chance),
       always_leave: Map.get(opts, :always_leave, false),
       password_chance: Map.get(opts, :password_chance, @password_chance)
     }}
  end
end
