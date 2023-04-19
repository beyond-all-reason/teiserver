defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc false
  use GenServer
  require Logger
  alias Teiserver.{Account, User}
  alias Central.Config
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  # Order of the queues matters
  @queues ~w(moderator contributor vip standard toxic)a

  @tick_interval 1_000

  @spec get_queue_length :: non_neg_integer()
  def get_queue_length() do
    call_login_throttle_server(:queue_size)
  end

  @spec attempt_login(T.userid()) :: boolean()
  def attempt_login(userid) do
    call_login_throttle_server({:attempt_login, userid})
  end

  @spec heartbeat :: non_neg_integer()
  def heartbeat() do
    call_login_throttle_server(:queue_size)
  end

  @spec startup :: any
  def startup() do
    send_login_throttle_server(:startup)
  end

  def send_login_throttle_server(msg) do
    case get_login_throttle_server_pid() do
      nil ->
        nil

      pid ->
        send(pid, msg)
    end
  end

  defp call_login_throttle_server(msg) do
    case get_login_throttle_server_pid() do
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

  def get_login_throttle_server_pid() do
    case Horde.Registry.lookup(Teiserver.ServerRegistry, "LoginThrottleServer") do
      [{pid, _}] ->
        pid

      _ ->
        nil
    end
  end

  @impl true
  def handle_call(:queue_size, _from, state) do
    result =
      ~w(standard_queue vip_queue contributor_queue moderator_queue toxic_queue)a
      |> Enum.map(fn key ->
        Map.get(state, key, []) |> Enum.count()
      end)
      |> Enum.sum()

    {:reply, result, state}
  end

  def handle_call({:attempt_login, _userid}, _from, %{use_queues: false} = state) do
    {:reply, :login, state}
  end

  def handle_call({:attempt_login, userid}, _from, state) do
    {new_state, result} = can_login?(userid, state)

    {:reply, result, new_state}
  end

  @impl true
  def handle_info(%{channel: "teiserver_telemetry", event: :data, data: data}, state) do
    new_state = apply_server_capacity(state, data)
    {:noreply, new_state}
  end

  def handle_info(:tick, state) do
    {remaining_capacity, server_usage} = Teiserver.User.server_capacity()

    {:noreply, %{state |
      remaining_capacity: remaining_capacity,
      server_usage: server_usage
    }}
  end

  def handle_info(:startup, _) do
    :timer.send_interval(@tick_interval, :tick)
    telemetry_data = (Central.cache_get(:application_temp_cache, :telemetry_data) || %{})
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_telemetry")

    state = %{
       queues: @queues |> Map.new(fn q -> {q, []} end),
       recent_logins: [],
       heartbeats: %{},
       remaining_capacity: 0,
       server_usage: 0,
       use_queues: true,
     }
     |> apply_server_capacity(telemetry_data)

    {:noreply, state}
  end

  @doc """
  If the queues are empty you get a true result
  If there is a queue you get a false result
  """
  @spec can_login?(T.userid(), map()) :: {map(), boolean()}
  def can_login?(userid, state) do
    category = categorise_user(userid)

    cond do
      category == :instant ->
        Logger.warn("instant")
        new_state = accept_login(state)
        {new_state, true}

      state.remaining_capacity < 1 ->
        Logger.warn("no capacity")
        queue = Map.get(state.queues, category, [])
        new_queue = [userid | queue]
        new_queue_map = Map.put(state.queues, category, new_queue)
        new_state = Map.put(state, :queues, new_queue_map)

        {new_state, false}

      true ->
        IO.puts ""
        IO.inspect state.remaining_capacity, label: "remaining_capacity"
        IO.puts ""

        Logger.warn("default")

        # Of the queues ahead of us, are any occupied?
        # this goes through every relevant queue and returns true
        # if all of them are empty
        empty_queues = @queues
          |> Enum.take_while(fn queue -> queue != category end)
          |> Kernel.++([category])
          |> Enum.map(fn key ->
            queue = Map.get(state.queues, key)
            Enum.empty?(queue)
          end)
          |> Enum.all?()

        if empty_queues do
          new_state = accept_login(state)
          {new_state, true}
        else
          queue = Map.get(state.queues, category, [])
          new_queue = [userid | queue]
          new_queue_map = Map.put(state.queues, category, new_queue)
          new_state = Map.put(state, :queues, new_queue_map)

          {new_state, false}
        end
    end
  end

  defp accept_login(%{recent_logins: recent_logins, remaining_capacity: remaining_capacity} = state) do
    %{state |
      recent_logins: [System.system_time(:microsecond) | recent_logins],
      remaining_capacity: remaining_capacity - 1
    }
  end

  defp categorise_user(userid) do
    user = Account.get_user_by_id(userid)

    cond do
      User.is_bot?(user) -> :instant
      User.has_all_roles?(user, ["Moderator"]) -> :moderator
      User.has_all_roles?(user, ["Contributor"]) -> :contributor
      User.has_all_roles?(user, ["VIP"]) -> :vip
      user.behaviour_score < 5000 -> :toxic
      true -> :standard
    end
  end

  @spec apply_server_capacity(Map.t(), Map.t()) :: {non_neg_integer(), number()}
  defp apply_server_capacity(state, telemetry_data) do
    total_limit = Config.get_site_config_cache("system.User limit")

    client_count =
      telemetry_data
      |> Map.get(:client, %{})
      |> Map.get(:total, 0)

    remaining_capacity = total_limit - client_count
    server_usage = max(client_count, 1) / total_limit

    IO.puts ""
    IO.inspect {remaining_capacity, server_usage}
    IO.puts ""

    %{state |
      remaining_capacity: remaining_capacity,
      server_usage: server_usage
    }
  end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_) do
    Logger.metadata(request_id: "LoginThrottleServer")

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "LoginThrottleServer",
      "LoginThrottleServer"
    )

    {:ok, %{}}
  end
end
