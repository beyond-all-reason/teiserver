defmodule Teiserver.Agents.InOutAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib
  require Logger

  @tick_period 2000
  @logout_chance 0.1
  @login_chance 0.2

  def handle_info(:startup, state) do
    :timer.send_interval(@tick_period, self(), :tick)

    {:noreply, do_login(state)}
  end

  def handle_info(:tick, %{logged_in: true} = state) do
    state = if :rand.uniform() <= @logout_chance do
      do_logout(state)
    else
      state
    end

    {:noreply, state}
  end

  def handle_info(:tick, %{logged_in: false} = state) do
    state = if :rand.uniform() <= @login_chance do
      do_login(state)
    else
      state
    end

    {:noreply, state}
  end

  def handle_info({:ssl, _socket, data}, state) do
    new_state = data
    |> AgentLib.translate
    |> Enum.reduce(state, fn data, acc ->
      handle_msg(data, acc)
    end)

    {:noreply, new_state}
  end

  def handle_info({:ssl_closed, _socket}, state) do
    {:noreply, %{state | logged_in: false, socket: nil}}
  end

  defp do_login(state) do
    socket = AgentLib.get_socket()

    {:success, user} = AgentLib.login(socket, %{
      name: "InAndOut_#{state.number}",
      email: "InAndOut_#{state.number}@agent_email",
      extra_data: %{}
    })

    # Reset flood protection
    ConCache.put(:teiserver_login_count, user.id, 0)

    %{state | socket: socket, logged_in: true}
  end

  defp do_logout(state) do
    AgentLib._send(state.socket, %{cmd: "c.auth.disconnect"})
    %{state | logged_in: false}
  end

  defp handle_msg(nil, state), do: state
  defp handle_msg(%{"cmd" => "s.system.pong"}, state) do
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
       logged_in: false,
       socket: nil
     }}
  end
end
