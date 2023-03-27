defmodule Teiserver.Agents.IdleAgentServer do
  @doc """
  Logs on, waits around and sends a ping every @tick_ms
  Also requests news and "new login" type information 5 seconds after login and every @info_ms after that
  """
  use GenServer
  alias Teiserver.Agents.AgentLib

  @tick_ms 20000
  @info_ms 60000

  def handle_info(:startup, state) do
    AgentLib.post_agent_update(state.id, "idle startup")

    socket = AgentLib.get_socket()

    AgentLib.login(socket, %{
      name: "Idle_#{state.number}",
      email: "Idle_#{state.number}@agents",
      extra_data: %{}
    })

    :timer.send_interval(@tick_ms, self(), :tick)
    :timer.send_interval(@info_ms, self(), :info)

    :timer.send_after(1000, self(), :info)

    {:noreply, %{state | socket: socket}}
  end

  def handle_info(:tick, state) do
    AgentLib._send(state.socket, %{cmd: "c.system.ping"})
    AgentLib.post_agent_update(state.id, "idle pinged")
    {:noreply, state}
  end

  def handle_info(:info, state) do
    AgentLib._send(state.socket, %{cmd: "c.news.get_latest_game_news", category: "Game news"})
    {:noreply, state}
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

  defp handle_msg(%{"cmd" => "s.system.pong"}, state) do
    state
  end

  defp handle_msg(%{"cmd" => "s.news.get_latest_game_news", "post" => _post}, state) do
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
       socket: nil
     }}
  end
end
