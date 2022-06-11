defmodule Teiserver.Agents.MatchmakingAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  require Logger

  @tick_period 5_000
  @decline_chance 0.2

  @leave_delay 5_000
  @rejoin_delay 2_000

  def handle_info(:startup, state) do
    socket = AgentLib.get_socket()
    AgentLib.login(socket, %{
      name: "Matchmaking_#{state.name}",
      email: "Matchmaking_#{state.name}@agents",
      bot: true
    })

    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    new_state = cond do
      state.queues != [] ->
        state

      # Not part of any queues, we query the queue list and will pick one at random
      state.queues == [] ->
        get_queues(state)
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

  def handle_info({:set_allow_join, value}, state) do
    {:noreply, %{state | allow_join: value}}
  end

  def handle_info(:leave_lobby, state) do
    :timer.send_after(@rejoin_delay, {:set_allow_join, true})
    AgentLib._send(state.socket, %{cmd: "c.lobby.leave"})
    {:noreply, state}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.matchmaking.query", "result" => "success", "queues" => queues}, state) do
    queue_ids = queues
      |> Enum.map(fn q -> q["id"] end)

    case queue_ids do
      [] ->
        state

      _ ->
        if state.allow_join do
          queue_id = Enum.random(queue_ids)
          cmd = %{cmd: "c.matchmaking.join_queue", queue_id: queue_id}
          AgentLib._send(state.socket, cmd)
        end
        state
    end
  end
  defp handle_msg(%{"cmd" => "s.matchmaking.join_queue", "result" => "success", "queue_id" => queue_id}, state) do
    %{state | queues: [queue_id]}
  end
  defp handle_msg(%{"cmd" => "s.matchmaking.match_ready", "match_id" => match_id}, state) do
    if :rand.uniform() <= state.decline_chance do
      cmd = %{cmd: "c.matchmaking.decline", match_id: match_id}
      AgentLib._send(state.socket, cmd)
      :timer.send_after(@rejoin_delay, {:set_allow_join, true})
      %{state | queues: [],  allow_join: false}
    else
      cmd = %{cmd: "c.matchmaking.accept", match_id: match_id}
      AgentLib._send(state.socket, cmd)
      %{state | queues: [],  allow_join: false}
    end
  end

  defp handle_msg(%{"cmd" => "s.matchmaking.match_cancelled"}, state) do
    %{state | queues: [],  allow_join: true}
  end

  defp handle_msg(%{"cmd" => "s.matchmaking.match_declined"}, state) do
    %{state | queues: [],  allow_join: true}
  end


  defp handle_msg(%{"cmd" => "s.lobby.remove_user"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.leave"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.updated"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.add_user"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.updated_client_battlestatus"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.force_join"}, state) do
    :timer.send_after(@leave_delay, :leave_lobby)
    %{state | queues: [],  allow_join: false}
  end

  defp handle_msg(%{"cmd" => "s.communication.received_direct_message"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.announce"}, state), do: state
  defp handle_msg(%{"cmd" => "s.lobby.message"}, state), do: state

  defp get_queues(state) do
    cmd = %{cmd: "c.matchmaking.query", query: %{}}
    AgentLib._send(state.socket, cmd)
    state
  end

  # defp leave_battle(state) do
  #   AgentLib._send(state.socket, %{cmd: "c.lobby.leave"})
  #   AgentLib.post_agent_update(state.id, "left battle")
  #   %{state | lobby_id: nil}
  # end

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
       queues: [],
       socket: nil,
       reject: Map.get(opts, :reject, false),
       allow_join: true,
       decline_chance: Map.get(opts, :decline_chance, @decline_chance)
     }}
  end
end
