defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc """
  Users attempt to login, if they validate the login process a final call is
  made to this server.

  They call `attempt_login(userid)`, a `true` response means they are good to login
  while a `false` response means they are now in the queue

  """
  use GenServer
  require Logger
  alias Teiserver.{Account, User}
  alias Central.Config
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  # Order of the queues matters
  @all_queues ~w(moderator contributor vip standard toxic)a

  # Queues not impacted with special rules
  @standard_queues ~w(moderator contributor vip standard)a

  @tick_interval 1_000
  @release_interval 100
  @heartbeat_expiry 5_000
  @arrival_expiry 60_000

  @all_must_wait true

  # login_recent_age_search is the distance (in time) we record logins
  # for the purposes of "recent" logins
  @login_recent_age_search @tick_interval

  # max login rate is the number of logins we can have as recent
  @max_login_rate @tick_interval / @release_interval * 2

  @spec get_queue_length :: non_neg_integer()
  def get_queue_length() do
    call_login_throttle_server(:queue_size)
  end

  @doc """
  This is the function call used as part of login attempts.
  """
  @spec attempt_login(pid(), T.userid()) :: boolean()
  def attempt_login(pid, userid) do
    call_login_throttle_server({:attempt_login, pid, userid})
  end

  @doc """
  This refreshes the heartbeat timer for a given pid. A heartbeat here is
  when a client tells the server they are still waiting to login.
  If a client doesn't send heartbeats they get dropped from the queue
  """
  @spec heartbeat(pid(), T.userid()) :: :ok
  def heartbeat(pid, userid) do
    send_login_throttle_server({:heartbeat, pid, userid})
  end

  @spec set_value(atom, any) :: :ok
  def set_value(key, value) do
    send_login_throttle_server({:set_value, key, value})
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

  def handle_call({:attempt_login, _pid, _userid}, _from, %{use_queues: false} = state) do
    {:reply, :login, state}
  end

  def handle_call({:attempt_login, pid, userid}, _from, state) do
    {new_state, result} = can_login?(pid, userid, state)

    {:reply, result, new_state}
  end

  @impl true
  def handle_info(%{channel: "teiserver_telemetry", event: :data, data: data}, state) do
    new_state = apply_server_capacity(state, data)
    {:noreply, new_state}
  end

  def handle_info(:release, %{awaiting_release: []} = state) do
    {:noreply, state}
  end

  # Releases the head of the awaiting release list
  def handle_info(:release, state) do
    [{pid, userid} | remaining] = state.awaiting_release

    send(pid, {:login_accepted, userid})

    new_state = %{
      state
      | awaiting_release: remaining,
        remaining_capacity: state.remaining_capacity - 1
    }

    {:noreply, new_state}
  end

  # Check stats, see if we can let anybody else login right now
  def handle_info(:tick, state) do
    # Strip out invalid heartbeats
    heartbeat_max_age = System.system_time(:millisecond) - @heartbeat_expiry

    dropped_users =
      state.heartbeats
      |> Map.filter(fn {_key, {_pid, last_time}} ->
        last_time < heartbeat_max_age
      end)
      |> Map.keys()

    new_queues =
      @all_queues
      |> Map.new(fn key ->
        existing_queue = Map.get(state.queues, key)

        new_queue =
          existing_queue
          |> Enum.reject(fn userid -> Enum.member?(dropped_users, userid) end)

        {key, new_queue}
      end)

    new_heartbeats = Map.drop(state.heartbeats, dropped_users)

    min_recent_age = System.system_time(:millisecond) - @login_recent_age_search

    new_recent_logins =
      state.recent_logins
      |> Enum.reject(fn t ->
        t < min_recent_age
      end)

    # Cleanup arrivals
    arrival_max_age = System.system_time(:millisecond) - @arrival_expiry

    new_arrival_times =
      state.arrival_times
      |> Map.filter(fn {_key, last_time} ->
        last_time > arrival_max_age
      end)

    send(self(), :dequeue)

    {:noreply,
     %{
       state
       | heartbeats: new_heartbeats,
         queues: new_queues,
         recent_logins: new_recent_logins,
         arrival_times: new_arrival_times
     }}
  end

  def handle_info(:dequeue, state) do
    new_state = dequeue_users(state)
    {:noreply, new_state}
  end

  # Handle a heartbeat from a pid
  def handle_info({:heartbeat, pid, userid}, state) do
    new_heartbeats =
      if Map.has_key?(state.heartbeats, userid) do
        Map.put(state.heartbeats, userid, {pid, System.system_time(:millisecond)})
      else
        state.heartbeats
      end

    {:noreply, %{state | heartbeats: new_heartbeats}}
  end

  def handle_info({:set_value, key, value}, state) do
    new_state =
      if Map.has_key?(state, key) do
        Map.put(state, key, value)
      else
        state
      end

    {:noreply, new_state}
  end

  def handle_info(:startup, _) do
    :timer.send_interval(@tick_interval, :tick)
    :timer.send_interval(@release_interval, :release)
    telemetry_data = Central.cache_get(:application_temp_cache, :telemetry_data) || %{}
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_telemetry")

    state =
      %{
        queues: @all_queues |> Map.new(fn q -> {q, []} end),
        recent_logins: [],
        heartbeats: %{},
        arrival_times: %{},
        awaiting_release: [],
        remaining_capacity: 0,
        server_usage: 0,
        use_queues: true,
        all_must_wait: @all_must_wait,
        standard_min_wait: Config.get_site_config_cache("system.Login throttle standard wait"),
        toxic_min_wait: Config.get_site_config_cache("system.Login throttle toxic wait")
      }
      |> apply_server_capacity(telemetry_data)

    {:noreply, state}
  end

  @doc """
  If the queues are empty you get a true result
  If there is a queue you get a false result
  """
  @spec can_login?(pid(), T.userid(), map()) :: {map(), boolean()}
  def can_login?(pid, userid, state) do
    category = categorise_user(userid)

    cond do
      category == :instant ->
        new_state = accept_login(state)
        {new_state, true}

      state.remaining_capacity < 1 ->
        new_state = add_user_to_queue(state, category, {pid, userid})
        {new_state, false}

      state.all_must_wait == true ->
        new_state = add_user_to_queue(state, category, {pid, userid})
        {new_state, false}

      # See below for comments on the bug
      true ->
        new_state = add_user_to_queue(state, category, {pid, userid})
        {new_state, false}

        # There is a bug where using this would cause some users to queue forever
        # true ->
        #   # Of the queues ahead of us, are any occupied?
        #   # this goes through every relevant queue and returns true
        #   # if all of them are empty
        #   empty_queues =
        #     @all_queues
        #     |> Enum.take_while(fn queue -> queue != category end)
        #     |> Kernel.++([category])
        #     |> Enum.map(fn key ->
        #       queue = Map.get(state.queues, key)
        #       Enum.empty?(queue)
        #     end)
        #     |> Enum.all?()

        #   if empty_queues and category != :toxic do
        #     new_state = accept_login(state)
        #     {new_state, true}
        #   else
        #     new_state = add_user_to_queue(state, category, {pid, userid})
        #     {new_state, false}
        #   end
    end
  end

  # If a user isn't allowed to login right away they need to be queued up
  # this function takes care of all the work around that
  @spec add_user_to_queue(map(), atom, {pid, T.userid()}) :: map()
  defp add_user_to_queue(state, category, {pid, userid}) do
    queue = Map.get(state.queues, category, [])
    new_queue = queue ++ [userid]
    new_queue_map = Map.put(state.queues, category, new_queue)

    new_heartbeats = Map.put(state.heartbeats, userid, {pid, System.system_time(:millisecond)})

    new_arrivals = Map.put(state.arrival_times, userid, System.system_time(:millisecond))

    Map.merge(state, %{
      queues: new_queue_map,
      heartbeats: new_heartbeats,
      arrival_times: new_arrivals
    })
  end

  # This takes one user out of a queue at a time
  # starting with the most relevant queues
  defp dequeue_users(state) do
    dequeue_users(state, state.remaining_capacity)
  end

  defp dequeue_users(state, 0), do: state

  defp dequeue_users(state, empty_count) do
    now_ms = System.system_time(:millisecond)

    # For our first part, we try to find a user to dequeue
    userid =
      @standard_queues
      |> Enum.reduce(nil, fn
        key, nil ->
          queue = Map.get(state.queues, key)

          if Enum.empty?(queue) do
            nil
          else
            userid = hd(queue)

            arrival_time = Map.get(state.arrival_times, userid, 91_682_272_843_772)
            waited_for = now_ms - arrival_time

            if waited_for > state.standard_min_wait do
              userid
            else
              nil
            end
          end

        # A return of anything other than nil means
        # we have found what we wanted
        _key, userid ->
          userid
      end)

    if userid do
      new_state = add_user_to_release_list(state, userid)
      dequeue_users(new_state, empty_count - 1)
    else
      # No standard user found
      dequeue_toxic_users(state, empty_count)
    end
  end

  defp dequeue_toxic_users(%{queues: %{toxic: []}} = state, _), do: state

  defp dequeue_toxic_users(state, empty_count) do
    # Toxic users have to wait a certain length of time to be able to login
    userids =
      state.queues.toxic
      |> Enum.slice(0..empty_count)
      |> Enum.filter(fn userid ->
        arrival_time = Map.get(state.arrival_times, userid, 91_682_272_843_772)
        waited_for = System.system_time(:millisecond) - arrival_time

        waited_for > state.toxic_min_wait
      end)

    if Enum.empty?(userids) do
      state
    else
      userids
      |> Enum.reduce(state, fn userid, acc_state ->
        add_user_to_release_list(acc_state, userid)
      end)
    end
  end

  defp add_user_to_release_list(state, userid) do
    {pid, _hb} = state.heartbeats[userid]

    # Remove this user from heartbeats and queues
    new_queues =
      @all_queues
      |> Map.new(fn key ->
        existing_queue = Map.get(state.queues, key)

        new_queue =
          existing_queue
          |> Enum.reject(fn q_userid -> q_userid == userid end)

        {key, new_queue}
      end)

    new_heartbeats = Map.drop(state.heartbeats, [userid])

    new_awaiting_release = state.awaiting_release ++ [{pid, userid}]

    %{
      state
      | recent_logins: [System.system_time(:millisecond) | state.recent_logins],
        remaining_capacity: state.remaining_capacity - 1,
        queues: new_queues,
        heartbeats: new_heartbeats,
        awaiting_release: new_awaiting_release
    }
  end

  # When a login is accepted and we want to update certain metrics right away
  defp accept_login(
         %{recent_logins: recent_logins, remaining_capacity: remaining_capacity} = state
       ) do
    %{
      state
      | recent_logins: [System.system_time(:millisecond) | recent_logins],
        remaining_capacity: remaining_capacity - 1
    }
  end

  @spec categorise_user(T.userid()) :: atom
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

  @spec apply_server_capacity(Map.t(), Map.t()) :: map()
  defp apply_server_capacity(state, telemetry_data) do
    total_limit = Config.get_site_config_cache("system.User limit")

    client_count =
      telemetry_data
      |> Map.get(:client, %{})
      |> Map.get(:total, 0)

    recent_count = Enum.count(state.recent_logins)

    # Remaining capacity is the lowest of server limit and login rate limit
    remaining_capacity =
      min(total_limit - client_count, @max_login_rate - recent_count) |> round()

    server_usage = max(client_count, 1) / total_limit

    %{state | remaining_capacity: remaining_capacity, server_usage: server_usage}
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
