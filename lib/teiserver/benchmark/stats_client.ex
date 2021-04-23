defmodule Teiserver.Benchmark.StatsClient do
  @moduledoc """
  A client that tracks various statistics
  """

  require Logger
  @report_interval 15_000
  @registration_interval 10_000
  @user_action_interval 30_000

  @users_per_tick 20

  use GenServer

  # GenServer callbacks
  def handle_info({:ping, p}, state) do
    new_state = %{state | pings: state.pings ++ [p]}
    {:noreply, new_state}
  end

  def handle_info(:report, state) do
    average_ping = Enum.sum(state.pings) / max(Enum.count(state.pings), 1)
    users = Registry.count(Teiserver.Benchmark.UserRegistry)

    # Print stats
    IO.puts("
Users: #{users}
Avg ping: #{round(average_ping * 100) / 100}ms, Pings: #{Enum.count(state.pings)}
")

    {:noreply, %{state | pings: []}}
  end

  def handle_info(:register, state) do
    add_connections(state)
    {:noreply, %{state | tick: state.tick + 1}}
  end

  def handle_info({:begin, server, port}, state) do
    state =
      Map.merge(state, %{
        server: server,
        port: port
      })

    Logger.warn("Starting stats")
    :timer.send_interval(@registration_interval, self(), :register)
    send(self(), :register)

    :timer.send_interval(@report_interval, self(), :report)

    {:noreply, state}
  end

  defp add_connections(state) do
    pid = self()

    1..@users_per_tick
    |> Enum.each(fn i ->
      id = state.tick * 1000 + i

      {:ok, _pid} =
        DynamicSupervisor.start_child(Teiserver.Benchmark.UserSupervisor, {
          Teiserver.Benchmark.UserClient,
          name: via_user_tuple(id),
          data: %{
            interval: @user_action_interval,
            # delay: :random.uniform(@user_action_interval),
            delay: i * 1000,
            id: id,
            tick: state.tick,
            stats: pid,
            server: state.server,
            port: state.port
          }
        })
    end)
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    {:ok,
     %{
       tick: 1,
       users: 0,
       pings: []
     }}
  end

  defp via_user_tuple(id) do
    {:via, Registry, {Teiserver.Benchmark.UserRegistry, id}}
  end
end
