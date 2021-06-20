defmodule Teiserver.Director do
  alias Teiserver.Battle.BattleLobby
  alias Teiserver.User
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

    ConCache.put(:teiserver_consul_pids, :coordinator, coordinator_pid)
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

  @spec get_consul_pid(T.battle_id()) :: pid() | nil
  def get_consul_pid(battle_id) do
    ConCache.get(:teiserver_consul_pids, battle_id)
  end

  @spec start_consul(T.battle_id()) :: pid()
  def start_consul(battle_id) do
    {:ok, consul_pid} =
      DynamicSupervisor.start_child(Teiserver.Director.DynamicSupervisor, {
        Teiserver.Director.ConsulServer,
        name: Teiserver.Director.CoordinatorServer,
        data: %{
          battle_id: battle_id,
        }
      })

    send(consul_pid, :startup)
    consul_pid
  end

  @spec cast_consul(T.battle_id(), any) :: any
  def cast_consul(battle_id, msg) when is_integer(battle_id) do
    case get_consul_pid(battle_id) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_consul(pid() | T.battle_id(), any) :: any
  def call_consul(battle_id, msg) when is_integer(battle_id) do
    case get_consul_pid(battle_id) do
      nil -> nil
      pid -> GenServer.call(pid, msg)
    end
  end

  def handle_in(userid, msg, battle_id) do
    Parser.handle_in(userid, msg, battle_id)
  end

  def close_battle(battle_id) do
    case get_consul_pid(battle_id) do
      nil -> nil
      pid ->
        ConCache.delete(:teiserver_consul_pids, battle_id)
        DynamicSupervisor.terminate_child(Teiserver.Director.DynamicSupervisor, pid)
    end
  end

  def send_to_host(from_id, battle_id, msg) do
    battle = BattleLobby.get_battle!(battle_id)
    # pid = Client.get_client_by_id(battle.founder_id).pid
    User.send_direct_message(from_id, battle.founder_id, msg)
    # send(pid, {:battle_updated, battle_id, {from_id, msg, battle_id}, :say})
    Logger.info("send_to_host - #{battle.id}, #{msg}")
  end
end
