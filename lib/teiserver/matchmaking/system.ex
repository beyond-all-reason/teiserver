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

    Supervisor.init(children, strategy: :rest_for_one)
  end
end
