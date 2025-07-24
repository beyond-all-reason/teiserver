defmodule Teiserver.Coordinator do
  @moduledoc false
  alias Teiserver.{Battle, CacheUser}
  alias Teiserver.Data.Types, as: T
  require Logger

  @spec do_start() :: :ok | :already_started
  defp do_start() do
    # Start the supervisor server
    result =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Coordinator.CoordinatorServer,
        name: Teiserver.Coordinator.CoordinatorServer, data: %{}
      })

    case result do
      {:ok, _coordinator_pid} -> :ok
      {:failure, "Already started"} -> :already_started
    end
  end

  @spec start_coordinator() :: :ok | {:failure, String.t()}
  def start_coordinator() do
    cond do
      get_coordinator_pid() != nil ->
        {:failure, "Already started"}

      true ->
        do_start()
    end
  end

  @spec get_coordinator_userid() :: T.userid()
  def get_coordinator_userid() do
    Teiserver.cache_get(:application_metadata_cache, "teiserver_coordinator_userid")
  end

  @spec get_coordinator_pid() :: pid() | nil
  def get_coordinator_pid() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "CoordinatorServer") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec cast_coordinator(any) :: any
  def cast_coordinator(msg) do
    case get_coordinator_pid() do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_coordinator(any) :: any
  def call_coordinator(msg) do
    case get_coordinator_pid() do
      nil -> nil
      pid -> GenServer.call(pid, msg)
    end
  end

  # Consul related stuff
  @spec get_consul_pid(T.lobby_id()) :: pid() | nil
  def get_consul_pid(lobby_id) do
    case Horde.Registry.lookup(Teiserver.ConsulRegistry, lobby_id) do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec start_all_consuls() :: :ok
  def start_all_consuls() do
    Battle.list_lobby_ids()
    |> Enum.each(fn id ->
      case get_consul_pid(id) do
        nil -> start_consul(id)
        _ -> :ok
      end
    end)
  end

  @spec start_consul(T.lobby_id()) :: pid()
  def start_consul(lobby_id) do
    {:ok, consul_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.DynamicSupervisor, {
        Teiserver.Coordinator.ConsulServer,
        name: "consul_#{lobby_id}",
        data: %{
          lobby_id: lobby_id
        }
      })

    consul_pid
  end

  @spec cast_consul(T.lobby_id(), any) :: any
  def cast_consul(nil, _), do: :ok

  def cast_consul(lobby_id, msg) when is_integer(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec send_consul(T.lobby_id(), any) :: any
  def send_consul(nil, _), do: :ok

  def send_consul(lobby_id, msg) when is_integer(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_consul(pid() | T.lobby_id(), any) :: any
  def call_consul(lobby_id, msg) when is_integer(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, msg)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  # Balancer related stuff
  @spec get_balancer_pid(T.lobby_id()) :: pid() | nil
  def get_balancer_pid(lobby_id) do
    case Horde.Registry.lookup(Teiserver.BalancerRegistry, lobby_id) do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @spec start_all_balancers() :: :ok
  def start_all_balancers() do
    Battle.list_lobby_ids()
    |> Enum.each(fn id ->
      case get_balancer_pid(id) do
        nil -> start_balancer(id)
        _ -> :ok
      end
    end)
  end

  @spec start_balancer(T.lobby_id()) :: pid()
  def start_balancer(lobby_id) do
    {:ok, balancer_pid} =
      DynamicSupervisor.start_child(Teiserver.Coordinator.BalancerDynamicSupervisor, {
        Teiserver.Game.BalancerServer,
        name: "balancer_#{lobby_id}",
        data: %{
          lobby_id: lobby_id
        }
      })

    balancer_pid
  end

  @spec cast_balancer(T.lobby_id(), any) :: any
  def cast_balancer(nil, _), do: :ok

  def cast_balancer(lobby_id, msg) when is_integer(lobby_id) do
    case get_balancer_pid(lobby_id) do
      nil -> nil
      pid -> GenServer.cast(pid, msg)
    end
  end

  @spec send_balancer(T.lobby_id(), any) :: any
  def send_balancer(nil, _), do: :ok

  def send_balancer(lobby_id, msg) when is_integer(lobby_id) do
    case get_balancer_pid(lobby_id) do
      nil -> nil
      pid -> send(pid, msg)
    end
  end

  @spec call_balancer(pid() | T.lobby_id(), any) :: any
  def call_balancer(lobby_id, msg) when is_integer(lobby_id) do
    case get_balancer_pid(lobby_id) do
      nil ->
        nil

      pid ->
        try do
          GenServer.call(pid, msg)

          # If the process has somehow died, we just return nil
        catch
          :exit, _ ->
            nil
        end
    end
  end

  # Other stuff
  @spec attempt_battlestatus_update(T.client(), T.lobby_id()) :: {boolean, map() | nil} | nil
  def attempt_battlestatus_update(client, lobby_id) do
    call_consul(lobby_id, {:request_user_change_status, client})
  end

  @spec close_lobby(T.lobby_id()) :: :ok
  def close_lobby(lobby_id) do
    case get_consul_pid(lobby_id) do
      nil ->
        nil

      p ->
        DynamicSupervisor.terminate_child(Teiserver.Coordinator.DynamicSupervisor, p)
    end

    case get_balancer_pid(lobby_id) do
      nil ->
        nil

      p ->
        DynamicSupervisor.terminate_child(Teiserver.Coordinator.BalancerDynamicSupervisor, p)
    end

    Teiserver.Throttles.stop_throttle("LobbyThrottle:#{lobby_id}")
    :ok
  end

  @spec create_report(T.report()) :: :ok
  def create_report(report) do
    cast_coordinator({:new_report, report.id})
  end

  @spec update_report(T.report(), atom) :: :ok
  def update_report(report, :respond) do
    case report.response_action do
      "Warn" ->
        send_to_user(
          report.target_id,
          "You have just received a formal warning, reason: #{report.response_text}."
        )

      _ ->
        nil
    end

    :ok
  end

  def update_report(_report, _reason) do
    :ok
  end

  # Commands for the coordinator account to perform
  @spec send_to_host(T.userid(), String.t()) :: :ok
  def send_to_host(nil, _), do: :ok

  def send_to_host(lobby_id, msg) do
    send_to_host(get_coordinator_userid(), lobby_id, msg)
  end

  @spec send_to_host(T.userid(), T.userid(), String.t()) :: :ok
  def send_to_host(nil, _, _), do: :ok

  def send_to_host(from_id, lobby_id, msg) do
    lobby = Battle.get_lobby(lobby_id)

    if lobby do
      CacheUser.send_direct_message(from_id, lobby.founder_id, msg)
    end

    :ok
  end

  @spec send_to_user(T.userid(), String.t()) :: :ok
  def send_to_user(userid, msg) do
    CacheUser.send_direct_message(get_coordinator_userid(), userid, msg)
  end

  @spec get_team_config(integer()) :: map()
  def get_team_config(lobby_id) do
    call_consul(lobby_id, :get_team_config)
  end

  # Debug stuff
  @spec list_all_internal_servers :: [T.lobby_id()]
  def list_all_internal_servers() do
    Horde.Registry.select(Teiserver.ServerRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end
end
