defmodule Teiserver.Bridge.BridgeSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(_) do
    DynamicSupervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    DynamicSupervisor.init(strategy: :one_for_one)
  end

  def try_to_start_bridge_services do
    case DynamicSupervisor.start_child(
           Teiserver.Bridge.BridgeSupervisor,
           Supervisor.child_spec({Nostrum.Application, []}, restart: :temporary)
         ) do
      {:ok, _nostrum_pid} ->
        Logger.info("Nostrum started successfully. Starting DiscordBridgeBot...")

        DynamicSupervisor.start_child(
          Teiserver.Bridge.BridgeSupervisor,
          Supervisor.child_spec(
            {Teiserver.Bridge.DiscordBridgeBot, name: Teiserver.Bridge.DiscordBridgeBot},
            restart: :temporary
          )
        )

      {:error, reason} ->
        Logger.error("Nostrum failed: #{inspect(reason)}. DiscordBridgeBot will NOT start.")
    end
  end
end
