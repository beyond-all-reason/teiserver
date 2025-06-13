defmodule Teiserver.Bridge.DiscordSystem do
  use DynamicSupervisor
  use Task

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    pid = DynamicSupervisor.init(strategy: :one_for_one)

    Task.async(fn ->
      DynamicSupervisor.start_child(
        Teiserver.Bridge.DiscordSystem,
        Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)
      )
    end)

    pid
  end
end
