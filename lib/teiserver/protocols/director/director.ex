defmodule Teiserver.Director do
  alias Teiserver.Battle
  alias Teiserver.Data.Types
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

  @spec handle_in(Types.userid(), String.t(), Types.battle_id()) :: :say | :handled
  def handle_in(userid, msg, battle_id) do
    battle = Battle.get_battle!(battle_id)

    cond do
      battle.director_mode == false ->
        :say

      String.slice(msg, 0..0) != "!" ->
        :say

      true ->
        parse_and_handle(userid, msg, battle)
        :handled
    end
  end

  @spec parse_and_handle(Types.userid(), String.t(), Map.t()) :: :ok
  defp parse_and_handle(userid, msg, battle) do
    [cmd, opts] =
      case String.split(msg, " ", parts: 2) do
        [cmd] -> [cmd, []]
        [cmd, parts] -> [cmd, String.split(parts, " ")]
      end

    do_handle(userid, cmd, opts, battle)
    :ok
  end

  @spec do_handle(Types.userid(), String.t(), [String.t()], Map.t()) :: :nomatch | :ok
  defp do_handle(_userid, "!start", _opts, battle) do
    send_to_host(battle, "!start")
  end

  defp do_handle(_, cmd, opts, _) do
    msg = "#{cmd}: #{Kernel.inspect(opts)}"
    Logger.error("director handle error: #{msg}")
    :nomatch
  end

  @spec send_to_host(Map.t(), String.t()) :: :ok
  defp send_to_host(battle, msg) do
    Logger.info("send_to_host - #{battle.id}, #{msg}")
    :ok
  end
end
