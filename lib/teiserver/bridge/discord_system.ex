defmodule Teiserver.Bridge.DiscordSystem do
  use DynamicSupervisor
  use Task

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  @impl true
  def init(_) do
    {:ok, sup_flags} = DynamicSupervisor.init(strategy: :one_for_one)

    if Teiserver.Communication.use_discord?() do
      Task.async(fn ->
        DynamicSupervisor.start_child(
          __MODULE__,
          Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)
        )
      end)
    end

    {:ok, sup_flags}
  end
end
