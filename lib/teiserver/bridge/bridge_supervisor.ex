defmodule Teiserver.Bridge.BridgeSupervisor do
  use DynamicSupervisor
  require Logger

  def start_link(_) do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      Supervisor.child_spec({Nostrum.Application, []}, restart: :temporary),
      {Teiserver.Bridge.DiscordBridgeBot, name: Teiserver.Bridge.DiscordBridgeBot}
    ]

    # Allows catching process exits
    Process.flag(:trap_exit, true)

    Supervisor.init(children, strategy: :rest_for_one)
  end

  def encapsulate_nostrum_startup do
    nostrum_pid =
      case Supervisor.start_child(__MODULE__, {Nostrum.Application, []}) do
        {:ok, pid} ->
          pid

        {:error, reason} ->
          Logger.error("Nostrum failed: #{inspect(reason)}. Ignoring failure.")
          []
      end

    nostrum_pid
  end

  def handle_info({:EXIT, _pid, reason}, state) do
    Logger.error("#{Teiserver.Bridge.BridgeServer.bot_name()} crashed: #{inspect(reason)}")
    {:noreply, state}
  end
end
