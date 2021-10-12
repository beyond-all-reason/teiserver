defmodule Teiserver.Coordinator do
  alias Teiserver.Battle.Lobby
  alias Teiserver.User
  # alias Teiserver.Client
  alias Teiserver.Data.Types, as: T
  alias Teiserver.Coordinator.Parser
  require Logger

  @spec do_start() :: :ok
  defp do_start() do
    # Start the supervisor server
    {:ok, _coordinator_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Coordinator.CoordinatorServer,
        name: Teiserver.Coordinator.CoordinatorServer,
        data: %{}
      })
    :ok
  end

  # @spec get_coordinator_pid() :: pid()
  # defp get_coordinator_pid() do
  #   ConCache.get(:teiserver_coordinator, :coordinator)
  # end

  @spec start_coordinator() :: :ok | {:failure, String.t()}
  def start_coordinator() do
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

  @spec get_consul_pid(T.lobby_id()) :: pid() | nil
  def get_consul_pid(lobby_id) do
    ConCache.get(:teiserver_consul_pids, lobby_id)
  end

  @spec start_consul(T.lobby_id()) :: pid()
  def start_consul(lobby_id) do
    {:ok, consul_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Coordinator.ConsulServer,
        name: "consul_#{lobby_id}",
        data: %{
          lobby_id: lobby_id,
        }
      })

    consul_pid
  end

  @spec cast_consul(T.lobby_id(), any) :: any
  def cast_consul(lobby_id, msg) when is_integer(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_consul(pid() | T.lobby_id(), any) :: any
  def call_consul(lobby_id, msg) when is_integer(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil -> nil
      pid -> GenServer.call(pid, msg)
    end
  end

  @spec allow_battlestatus_update?(T.client(), T.lobby_id()) :: {boolean, Map.t() | nil}
  def allow_battlestatus_update?(client, lobby_id) do
    call_consul(lobby_id, {:request_user_change_status, client})
  end

  @spec handle_in(T.userid(), String.t(), T.lobby_id()) :: :say | :handled
  def handle_in(userid, msg, lobby_id) do
    Parser.handle_in(userid, msg, lobby_id)
  end

  def close_battle(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil -> nil
      pid ->
        ConCache.delete(:teiserver_consul_pids, lobby_id)
        DynamicSupervisor.terminate_child(Teiserver.Coordinator.DynamicSupervisor, pid)
    end
  end

  def create_report(_user, _report) do
    # Do nothing
  end

  def update_report(user, report) do
    case report.response_action do
      "Warn" ->
        send_to_user(user.id, "You have just received a formal warning, reason: #{report.response_text}.")
      _ ->
        nil
    end
  end

  @spec send_to_host(T.userid(), String.t()) :: :ok
  def send_to_host(lobby_id, msg) do
    send_to_host(get_coordinator_userid(), lobby_id, msg)
  end

  @spec send_to_host(T.userid(), T.userid(), String.t()) :: :ok
  def send_to_host(from_id, lobby_id, msg) do
    battle = Lobby.get_battle!(lobby_id)
    User.send_direct_message(from_id, battle.founder_id, msg)
    Logger.info("send_to_host - #{battle.id}, #{msg}")
  end

  @spec send_to_user(T.userid(), String.t()) :: :ok
  def send_to_user(userid, msg) do
    User.send_direct_message(get_coordinator_userid(), userid, msg)
  end
end
