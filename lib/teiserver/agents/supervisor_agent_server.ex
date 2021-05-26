defmodule Teiserver.Agents.SupervisorAgentServer do
  use GenServer
  alias Teiserver.Agents.AgentLib

  def handle_info(:begin, state) do
    AgentLib.post_agent_update(state.id, "Starting agents supervisor")

    add_servers("battlehost", 3)
    add_servers("battlehost", 4, 4, %{name: "stable", number: 4, leave_chance: 0, inaction_chance: 0})
    add_servers("battlehost", 5, 5, %{name: "unstable", number: 5, always_leave: true, leave_chance: 1, inaction_chance: 0})
    add_servers("battlejoin", 15)
    add_servers("idle", 5)

    AgentLib.post_agent_update(state.id, "Agent supervisor started")
    {:noreply, state}
  end

  @spec add_servers(String.t(), Integer.t()) :: :ok
  defp add_servers(type, count) do
    add_servers(
      type,
      1, count,
      %{}
    )
  end

  @spec add_servers(String.t(), Integer.t(), Integer.t(), Map.t()) :: :ok
  defp add_servers(type, start_at, end_at, opts) do
    module = lookup_module(type)

    start_at..end_at
    |> Enum.each(fn i ->
      {:ok, _pid} =
        DynamicSupervisor.start_child(Teiserver.Agents.DynamicSupervisor, {
          module,
          name: AgentLib.via_tuple(module, i),
          data: Map.merge(%{
            number: i,
            id: "#{type}-#{i}"
          }, opts)
        })

    end)
    :ok
  end

  @spec lookup_module(String.t()) :: any()
  defp lookup_module(type) do
    case type do
      "battlehost" -> Teiserver.Agents.BattlehostAgentServer
      "battlejoin" -> Teiserver.Agents.BattlejoinAgentServer
      "idle" -> Teiserver.Agents.IdleAgentServer
    end
  end

  # Startup
  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, [], opts)
  end

  def init(_opts) do
    {:ok, %{
      id: "agent_supervisor"
    }}
  end
end
