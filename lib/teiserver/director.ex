defmodule Teiserver.Director do
  # alias Teiserver.Battle.BattleLobby
  alias Teiserver.Client
  alias Teiserver.Data.Types, as: T
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

    ConCache.put(:teiserver_consuls, :coordinator, coordinator_pid)
    send(coordinator_pid, :begin)
    :ok
  end

  # @spec get_coordinator_pid() :: pid()
  # defp get_coordinator_pid() do
  #   ConCache.get(:teiserver_director, :coordinator)
  # end

  @spec start_director() :: :ok | {:failure, String.t()}
  def start_director() do
    cond do
      get_coordinator_userid() != nil ->
        {:failure, "Already started"}

      true ->
        do_start()
    end
  end

  @spec get_coordinator_userid() :: T.userid()
  def get_coordinator_userid() do
    ConCache.get(:application_metadata_cache, "teiserver_coordinator_userid")
  end

  @spec get_or_start_consul(T.battle_id()) :: pid()
  def get_or_start_consul(battle_id) do
    case ConCache.get(:teiserver_consuls, battle_id) do
      nil -> start_consul(battle_id)
      pid -> pid
    end
  end

  @spec start_consul(T.battle_id()) :: pid()
  defp start_consul(battle_id) do
    {:ok, consul_pid} =
      DynamicSupervisor.start_child(Teiserver.Director.DynamicSupervisor, {
        Teiserver.Director.ConsulServer,
        name: Teiserver.Director.CoordinatorServer,
        data: %{
          battle_id: battle_id,
        }
      })

    ConCache.put(:teiserver_consuls, battle_id, consul_pid)
    send(consul_pid, :startup)
    consul_pid
  end

  @spec cast_consul(T.battle_id(), any) :: :ok
  def cast_consul(%{consul_pid: consul_pid}, msg) do
    send(consul_pid, msg)
    :ok
  end

  def cast_consul(battle_id, msg) do
    send(get_or_start_consul(battle_id), msg)
    :ok
  end

  @spec call_consul(pid() | T.battle_id(), any) :: any
  def call_consul(%{consul_pid: consul_pid}, msg) do
    GenServer.call(consul_pid, msg)
  end

  def call_consul(battle_id, msg) do
    GenServer.call(get_or_start_consul(battle_id), msg)
  end

  def handle_in(userid, msg, battle_id) do
    Parser.handle_in(userid, msg, battle_id)
  end

  def send_to_host(from_id, battle, msg) do
    pid = Client.get_client_by_id(battle.founder_id).pid
    send(pid, {:battle_updated, battle.id, {from_id, msg, battle.id}, :say})
    Logger.info("send_to_host - #{battle.id}, #{msg}")
  end
end
