defmodule Teiserver.Matchmaking.System do
  @moduledoc """
  Everything required for matchmaking
  """

  use Supervisor

  def start_link(init_arg) do
    Supervisor.start_link(__MODULE__, init_arg, name: __MODULE__)
  end

  @impl true
  def init(_) do
    children = [
      Teiserver.Matchmaking.QueueRegistry,
      Teiserver.Matchmaking.QueueSupervisor
    ]

    # there are some matchmaking tests interacting with assets that stop the
    # QueueSupervisor. So when running tests with --repeat-until-failure xxx
    # it will start restarting this supervisor as well if using the default
    # restart parameter.
    # Setting it to an absurd number ensure we keep the restart isolated
    # Another way would be to restart the entire application supervisor for
    # each test, but that's a lot bigger change, maybe another day.
    restarts = if Mix.env() == :test, do: 10000, else: 3

    Supervisor.init(children, strategy: :rest_for_one, max_restarts: restarts)
  end
end
