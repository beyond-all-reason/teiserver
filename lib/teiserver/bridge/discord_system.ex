defmodule Teiserver.Bridge.DiscordSystem do
  @moduledoc false
  alias Teiserver.Communication

  use DynamicSupervisor
  use Task

  def start_link(_init_arg) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end


  @impl DynamicSupervisor
  def init(_init_arg) do
    start()
  end

  def start() do
    {:ok, sup_flags} = DynamicSupervisor.init(strategy: :one_for_one)

    if Communication.use_discord?() do
      Task.async(fn ->
        DynamicSupervisor.start_child(
          __MODULE__,
          Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)
        )
      end)
    end

    {:ok, sup_flags}
  end

  def restart() do
    case Process.whereis(Teiserver.Bridge.DiscordSupervisor) do
      pid when is_pid(pid) ->
        Supervisor.stop(pid, :normal)

      nil ->
        :already_down
    end

    start()
  end
end
