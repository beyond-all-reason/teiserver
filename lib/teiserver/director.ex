defmodule Teiserver.Director do
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.Data.Types
  alias Teiserver.Director.Parser
  require Logger

  @spec do_start() :: :ok
  defp do_start() do
    # Start the supervisor server
    {:ok, coordinator_pid} =
      DynamicSupervisor.start_child(Teiserver.Director.DynamicSupervisor, {
        Teiserver.Director.CoordinatorServer,
        name: Teiserver.Director.CoordinatorServer,
        data: %{}
      })

    ConCache.put(:teiserver_director, :coordinator, coordinator_pid)
    send(coordinator_pid, :begin)
    :ok
  end

  @spec get_coordinator_pid() :: pid()
  defp get_coordinator_pid() do
    ConCache.get(:teiserver_director, :coordinator)
  end

  @spec get_consul_pid(Types.battle_id()) :: pid()
  defp get_consul_pid(battle_id) do
    ConCache.get(:teiserver_director, battle_id)
  end

  @spec start_director() :: :ok | {:failure, String.t()}
  def start_director() do
    cond do
      Supervisor.count_children(Teiserver.Director.DynamicSupervisor)[:active] > 0 ->
        {:failure, "Already started"}

      true ->
        do_start()
        :ok
    end
  end

  def start_consul() do
    {:ok, coordinator_pid} =
      DynamicSupervisor.start_child(Teiserver.Director.DynamicSupervisor, {
        Teiserver.Director.ConsulServer,
        name: Teiserver.Director.CoordinatorServer,
        data: %{}
      })

    ConCache.put(:teiserver_director, :coordinator, coordinator_pid)
    send(coordinator_pid, :begin)
  end

  @spec add_to_battle(integer()) :: :ok
  def add_to_battle(battle_id) do
    send(get_coordinator_pid(), {:request_consul, battle_id})
    :ok
  end

  @spec remove_from_battle(integer()) :: :ok
  def remove_from_battle(battle_id) do
    send(get_coordinator_pid(), {:remove_consul, battle_id})
    :ok
  end

  @spec message_consul(Types.battle_id(), any) :: :ok
  def message_consul(battle_id, msg) do
    send(get_consul_pid(battle_id), msg)
    :ok
  end

  def handle_in(userid, msg, battle_id) do
    Parser.handle_in(userid, msg, battle_id)
  end
end
