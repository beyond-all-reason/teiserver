defmodule Teiserver.Agents.BattlehostAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  alias Teiserver.Lobby
  require Logger

  @tick_period 5000
  @inaction_chance 0.5
  @leave_chance 0.5
  @password_chance 0.5

  @map_hash "1565299817"
  @game_hash "156940380"
  @game_name "Beyond All Reason test-22409-ef148b9"
  @engine_version "105.1.1-1544-g058c8ea BAR105"

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()

    {:success, _user} =
      AgentLib.login(socket, %{
        name: "Battlehost_#{state.name}",
        email: "Battlehost_#{state.name}@agents",
        bot: true
      })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    battle = Lobby.get_lobby(state.lobby_id)

    new_state =
      cond do
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
    new_state =
      data
      |> AgentLib.translate()
      |> Enum.reduce(state, fn data, acc ->
        handle_msg(data, acc)
      end)

    {:noreply, new_state}
  end

  defp handle_msg(nil, state), do: state

  defp handle_msg(%{"error" => "not logged in"}, state) do
    state
  end

  defp handle_msg(
         %{"cmd" => "s.lobby_host.user_requests_to_join", "userid" => userid},
         %{reject: true} = state
       ) do
    cmd = %{
      cmd: "c.lobby_host.respond_to_join_request",
      userid: userid,
      response: "reject",
      reason: "because"
    }

    AgentLib._send(state.socket, cmd)
    state
  end

  defp handle_msg(
         %{"cmd" => "s.lobby_host.user_requests_to_join", "userid" => userid},
         %{reject: false} = state
       ) do
    cmd = %{cmd: "c.lobby_host.respond_to_join_request", userid: userid, response: "approve"}
    AgentLib._send(state.socket, cmd)
    state
  end

  defp handle_msg(%{"cmd" => "s.lobby.leave", "result" => "success"}, state) do
    %{state | lobby_id: nil}
  end

  defp handle_msg(%{"cmd" => "s.lobby.create", "lobby" => %{"id" => lobby_id}}, state) do
    %{state | lobby_id: lobby_id}
  end

  defp handle_msg(%{"cmd" => "s.communication.received_direct_message"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.announce"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.say"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.closed"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.add_user"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.remove_user"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.kick_user"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.updated"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.updated_client_battlestatus"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.set_modoptions"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.remove_modoptions"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.update_values"}, state), do: state

  defp handle_msg(%{"cmd" => "s.lobby.add_bot"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.update_bot"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.remove_bot"}, state), do: state

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
    # AgentLib._send(state.socket, %{cmd: "c.lobby.leave"})
    # AgentLib.post_agent_update(state.id, "left battle")
    # %{state | lobby_id: nil}
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
