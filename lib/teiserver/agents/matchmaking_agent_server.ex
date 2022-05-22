defmodule Teiserver.Agents.MatchmakingAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  require Logger

  @tick_period 5000
  @decline_chance 0.2

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

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.matchmaking.query", "result" => "success", "queues" => queues}, state) do
    queue_ids = queues
      |> Enum.map(fn q -> q["id"] end)

    case queue_ids do
      [] ->
        state

      _ ->
        queue_id = Enum.random(queue_ids)
        cmd = %{cmd: "c.matchmaking.join_queue", queue_id: queue_id}
        AgentLib._send(state.socket, cmd)
        state
    end
  end
  defp handle_msg(%{"cmd" => "s.matchmaking.join_queue", "result" => "success", "queue_id" => queue_id}, state) do
    %{state | queues: [queue_id]}
  end
  defp handle_msg(%{"cmd" => "s.matchmaking.match_ready", "match_id" => match_id}, state) do
    # if :rand.uniform() <= state.decline_chance do
      cmd = %{cmd: "c.matchmaking.decline", match_id: match_id}
      AgentLib._send(state.socket, cmd)
      %{state | queues: []}
    # else
    #   cmd = %{cmd: "c.matchmaking.ready", queue_id: queue_id}
    #   AgentLib._send(state.socket, cmd)
    # end
  end


  defp handle_msg(%{"cmd" => "s.matchmaking.match_declined"}, state), do: state

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
       decline_chance: Map.get(opts, :decline_chance, @decline_chance)
     }}
  end
end
