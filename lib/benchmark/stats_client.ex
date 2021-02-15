defmodule Teiserver.Benchmark.StatsClient do
  @moduledoc """
  A client that tracks various statistics
  """

  require Logger
  @tick_interval 2_000
  @users_per_tick 10
  @silents_per_tick 40

  use GenServer

  # GenServer callbacks
  def handle_info({:ping, p}, state) do
    new_state = %{state | pings: state.pings ++ [p]}
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    add_connections(state)

    average_ping = Enum.sum(state.pings)/max(Enum.count(state.pings),1)
    users = Registry.count(Teiserver.Benchmark.UserRegistry)
    silents = Registry.count(Teiserver.Benchmark.SilentRegistry)

    [_, l1, l5, l15] = ~r/load average: ([0-9\.]+), ([0-9\.]+), ([0-9\.]+)/
    |> Regex.run(:os.cmd('uptime') |> to_string)

    memory = :erlang.system_info(:allocated_areas)
    |> Enum.reduce(0, fn (value, acc) ->
      acc + case value do
        {_key, v} -> v
        {_key, v1, _v2} -> v1
      end
    end)

    memory = Float.round(memory / 1048576, 2)

    # Print stats
    IO.puts "Tick: #{state.tick}
Connections: #{users + silents} (users: #{users}, silents: #{silents})
Avg ping: #{round(average_ping*100)/100}ms, Pings: #{Enum.count(state.pings)}
Load: #{l1}, #{l5}, #{l15}
Memory: #{Kernel.inspect memory}MB
"

    new_state = %{state | tick: state.tick + 1, pings: []}
    {:noreply, new_state}
  end
  
  defp add_connections(state) do
    pid = self()
    1..@users_per_tick
    |> Parallel.each(fn i ->
      id = "user_#{state.tick}_#{i}"
      {:ok, _pid} = DynamicSupervisor.start_child(Teiserver.Benchmark.UserSupervisor, {
        Teiserver.Benchmark.UserClient,
        name: via_user_tuple(id),
        data: %{
          interval: (1000 + :random.uniform(1000)),
          id: id,
          tick: state.tick,
          stats: pid
        },
      })
    end)

    1..@silents_per_tick
    |> Parallel.each(fn i ->
      id = "silent_#{state.tick}_#{i}"
      {:ok, _pid} = DynamicSupervisor.start_child(Teiserver.Benchmark.SilentSupervisor, {
        Teiserver.Benchmark.SilentClient,
        name: via_silent_tuple(id),
        data: %{
          interval: (5000 + :random.uniform(10000)),
          id: id,
          tick: state.tick
        },
      })
    end)
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    Logger.warn("Starting stats")

    :timer.send_interval(@tick_interval, self(), :tick)
    {:ok, %{
      tick: 1,
      users: 0,
      silents: 0,
      pings: []
    }}
  end

  defp via_user_tuple(id) do
    {:via, Registry, {Teiserver.Benchmark.UserRegistry, id}}
  end

  defp via_silent_tuple(id) do
    {:via, Registry, {Teiserver.Benchmark.SilentRegistry, id}}
  end
end
