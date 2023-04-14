defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc false
  use GenServer
  require Logger
  alias Teiserver.{Account, User}
  alias Teiserver.Data.Types, as: T

  # Order of the queues matters
  @queues ~w(moderator contributor vip standard toxic)a

  @tick_interval 1_000

  @spec get_queue_length :: non_neg_integer()
  def get_queue_length() do
    call_login_throttle_server(:queue_size)
  end

  @spec attempt_login(T.userid()) :: :login | :queue
  def attempt_login(userid) do
    call_login_throttle_server({:attempt_login, userid})
  end

  @spec heartbeat :: non_neg_integer()
  def heartbeat() do
    call_login_throttle_server(:queue_size)
  end

  # def send_login_throttle_server(msg) do
  #   case get_login_throttle_server_pid() do
  #     nil ->
  #       nil

  #     pid ->
  #       send(pid, msg)
  #   end
  # end

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

  defp get_login_throttle_server_pid() do
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
    result = case can_login?(userid, state) do
      true -> :login
      false -> :queue
    end

    {:reply, result, state}
  end

  @doc """
  If the queues are empty you get a true result
  If there is a queue you get a false result
  """
  @spec can_login?(T.userid(), map()) :: boolean
  defp can_login?(userid, state) do
    case categorise_user(userid) do
      :instant -> true
      category ->
        # Of the queues ahead of us, are any occupied?
        # this goes through every relevant queue and returns true
        # if all of them are empty
        @queues
          |> Enum.take_while(fn queue -> queue != category end)
          |> Kernel.++([category])
          |> Enum.map(fn key ->
            queue = Map.get(state.queues, key)
            Enum.empty?(queue)
          end)
          |> Enum.all?()
    end
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

  @impl true
  def handle_info(:tick, state) do
    {remaining_capacity, server_usage} = Teiserver.User.server_capacity()

    {:noreply, %{state |
      remaining_capacity: remaining_capacity,
      server_usage: server_usage
    }}
  end

  # def handle_info({:login_attempt, userid}, state) do
  #   user = Account.get_user_by_id(userid)

  #   queue_key =
  #     cond do
  #       User.has_all_roles?(user, ["Moderator"]) -> :moderator_queue
  #       User.has_all_roles?(user, ["Contributor"]) -> :contributor_queue
  #       User.has_all_roles?(user, ["VIP"]) -> :vip_queue
  #       user.behaviour_score < 5000 -> :toxic_queue
  #       true -> :standard_queue
  #     end

  #   # Insert them into the front of the queue list
  #   queue = Map.get(state, queue_key, [])
  #   new_queue = [userid | queue]
  #   new_state = Map.put(state, queue_key, new_queue)

  #   {:noreply, new_state}
  # end

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_) do
    Logger.metadata(request_id: "LoginThrottleServer")
    :timer.send_interval(@tick_interval, :tick)

    # Update the queue pids cache to point to this process
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "LoginThrottleServer",
      "LoginThrottleServer"
    )

    {:ok,
     %{
       queues: @queues |> Map.new(fn q -> {q, []} end),
       recent_logins: [],
       heartbeats: %{},
       remaining_capacity: 0,
       server_usage: 0,
       use_queues: false
     }}
  end
end
