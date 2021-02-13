defmodule Mix.Tasks.Benchmark do
  use Mix.Task

  """
  :ranch.info()
  :ranch.procs(:tcp_echo, :acceptors)
  """

  def spawn_run do
    spawn fn ->
      run(nil)
    end
  end

  @shortdoc "Starts the benchmark procecess for the server"
  def run(_) do
    Mix.Task.run("app.start")

    children = [
      # Benchmark stuff
      {Registry, keys: :unique, name: Teiserver.Benchmark.UserRegistry},
      {Registry, keys: :unique, name: Teiserver.Benchmark.SilentRegistry},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Benchmark.UserSupervisor},
      {DynamicSupervisor, strategy: :one_for_one, name: Teiserver.Benchmark.SilentSupervisor},
      {Teiserver.Benchmark.StatsClient, name: Central.Account.RecentlyUsedCache},
    ]

    opts = [strategy: :one_for_one, name: Teiserver.Benchmark.Supervisor]
    start_result = Supervisor.start_link(children, opts)

    # Call all our sub function st
    {:ok, t} = Task.start(fn -> startup() end)
    send(t, :begin)
    
    :timer.sleep(180_000)

    start_result
  end

  defp startup() do
    receive do
      :begin -> nil
    end
  end
end