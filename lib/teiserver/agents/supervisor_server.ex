defmodule Teiserver.Agents.SupervisorServer do
  require Logger
  use GenServer
  alias Teiserver.Agents.AgentLib

  def handle_info(:begin, state) do
    Logger.info("Starting agents supervisor")

    add_servers("battlehost", 5)

    {:noreply, state}
  end

  @spec add_servers(String.t(), Integer.t()) :: :ok
  defp add_servers(type, count) do
    module = lookup_module(type)

    1..count
    |> Enum.each(fn i ->
      {:ok, _pid} =
        DynamicSupervisor.start_child(Teiserver.Agents.DynamicSupervisor, {
          module,
          name: AgentLib.via_tuple(module, i),
          data: %{
            number: i,
            id: "#{type}-#{i}"
          }
        })
    end)
    :ok
  end

  @spec lookup_module(String.t()) :: any()
  defp lookup_module(type) do
    case type do
      "battlehost" -> Teiserver.Agents.BattlehostServer
    end
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    {:ok, %{}}
  end
end
