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

  @spec start :: {:ok, any()}
  def start do
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

  @spec async_nolink_restart(pid()) :: :ok
  def async_nolink_restart(notify_pid) do
    Task.start(fn -> restart(notify_pid) end)

    :ok
  end

  @spec restart(pid()) :: :ok
  def restart(notify_pid) do
    if pid = Process.whereis(Teiserver.Bridge.DiscordSupervisor) do
      DynamicSupervisor.terminate_child(__MODULE__, pid)
    end

    start()

    Process.send(notify_pid, :discord_bridge_restarted, [])

    :ok
  end
end
