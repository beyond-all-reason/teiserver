defmodule Mix.Tasks.Benchmark do
  @moduledoc """
  Used to stress test a server. Will gradually spawn users until stopped.
  
  Usage:
    
    mix benchmark server port
  
  e.g.
    
    mix benchmark example.com 8200

  """
  use Mix.Task

  @shortdoc "Starts the benchmark procecess for the server"
  def run([server, port]) do
    Mix.Task.run("app.start")
    Logger.configure(level: :info)

    children = [
      # Benchmark stuff
      {Registry, keys: :unique, name: Teiserver.Benchmark.UserRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Benchmark.UserSupervisor},
      {Teiserver.Benchmark.StatsClient, name: Teiserver.Benchmark.StatsClient}
    ]

    opts = [strategy: :one_for_one, name: Teiserver.Benchmark.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    # Call all our sub function startup
    {:ok, t} = Task.start(fn -> startup() end)
    send(t, :begin)
    send(Teiserver.Benchmark.StatsClient, {:begin, server, port})

    :timer.sleep(300_000)

    start_result
  end

  defp startup() do
    receive do
      :begin -> nil
    end
  end
end
