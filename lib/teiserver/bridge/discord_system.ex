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

  @spec restart(pid()) :: :ok
  def restart(notify_pid) do
    Task.start(fn ->
      if Communication.use_discord?() do
        perform_restart(notify_pid)
      else
        Process.send(notify_pid, {:discord_bridge_restart_result, :disabled_by_configuration}, [])
      end
    end)

    :ok
  end

  @spec perform_restart(pid()) :: :ok
  defp perform_restart(notify_pid) do
    _termination_result =
      DynamicSupervisor.terminate_child(
        __MODULE__,
        Process.whereis(Teiserver.Bridge.DiscordSupervisor)
      )

    spec = Supervisor.child_spec(Teiserver.Bridge.DiscordSupervisor, restart: :temporary)

    case DynamicSupervisor.start_child(
           __MODULE__,
           spec
         ) do
      {:ok, _pid} ->
        Process.send(notify_pid, {:discord_bridge_restart_result, :restarted}, [])

      {:ok, _pid, _info} ->
        Process.send(notify_pid, {:discord_bridge_restart_result, :restarted}, [])

      _error ->
        Process.send(notify_pid, {:discord_bridge_restart_result, :failed_to_restart}, [])
    end

    :ok
  end
end
