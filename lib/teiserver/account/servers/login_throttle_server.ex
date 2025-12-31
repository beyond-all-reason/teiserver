defmodule Teiserver.Account.LoginThrottleServer do
  @moduledoc """
  Users attempt to login, if they validate the login process a final call is
  made to this server.

  They call `attempt_login(userid)`, a `true` response means they are good to login
  while a `false` response means they are now in the queue

  The server manages multiple queues based on the categorisation of user. Higher priority queues are always called on first but each queue uses a first-in-first-out policy.

  """
  use GenServer
  require Logger
  alias Teiserver.{Account, CacheUser}
  alias Teiserver.Config
  alias Teiserver.Data.Types, as: T
  alias Phoenix.PubSub

  # Order of the queues matters
  @queues ~w(moderator core contributor vip volunteer standard toxic)a

  @default_tick_period 500
  @releases_per_tick 3

  @heartbeat_expiry 5_000
  @login_recent_age_search 60_000

  @min_wait 0

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

  @spec set_tick_period(non_neg_integer()) :: :ok
  def set_tick_period(new_interval) do
    send_login_throttle_server({:set_tick_period, new_interval})
  end

  @spec get_state :: any
  def get_state() do
    case get_login_throttle_server_pid() do
      nil ->
        nil

      pid ->
        :sys.get_state(pid)
    end
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
      @queues
      |> Enum.map(fn q ->
        String.to_atom("#{q}_queue")
      end)
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

  # Check stats, see if we can let anybody else login right now
  def handle_info(:tick, state) do
    # Strip out invalid heartbeats
    heartbeat_max_age = System.system_time(:millisecond) - @heartbeat_expiry

    # Dropped users are users who've not updated their heartbeat for a bit
    # we assume they've left the queue
    dropped_users =
      state.heartbeats
      |> Map.filter(fn {_key, {_pid, last_time}} ->
        last_time < heartbeat_max_age
      end)
      |> Map.keys()

    # Updated queues based on dropped users being removed
    new_queues =
      if Enum.empty?(dropped_users) do
        state.queues
      else
        @queues
        |> Map.new(fn key ->
          existing_queue = Map.get(state.queues, key)

          new_queue =
            existing_queue
            |> Enum.reject(fn userid -> Enum.member?(dropped_users, userid) end)

          {key, new_queue}
        end)
      end

    # Update the heartbeats
    new_heartbeats = Map.drop(state.heartbeats, dropped_users)

    # Update the recent logins
    min_recent_age = System.system_time(:millisecond) - @login_recent_age_search

    new_recent_logins =
      state.recent_logins
      |> Enum.reject(fn t ->
        t < min_recent_age
      end)

    new_state = %{
      state
      | heartbeats: new_heartbeats,
        queues: new_queues,
        recent_logins: new_recent_logins
    }

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_liveview_login_throttle",
      %{
        channel: "teiserver_liveview_login_throttle",
        event: :tick,
        heartbeats: new_heartbeats,
        queues: new_queues,
        recent_logins: new_recent_logins
      }
    )

    # Now we do the releases
    new_state = dequeue_users(new_state)

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

  def handle_info(:disable_tick_timer, state) do
    :timer.cancel(state.tick_timer_ref)
    {:noreply, %{state | tick_timer_ref: nil}}
  end

  def handle_info({:set_tick_period, new_period}, state) do
    if state.tick_timer_ref do
      :timer.cancel(state.tick_timer_ref)
    end

    tick_timer_ref = :timer.send_interval(new_period, :tick)

    {:noreply, %{state | tick_timer_ref: tick_timer_ref}}
  end

  def handle_info(:startup, _) do
    tick_timer_ref = :timer.send_interval(@default_tick_period, :tick)
    telemetry_data = Teiserver.cache_get(:application_temp_cache, :telemetry_data) || %{}
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_telemetry")

    state =
      %{
        queues: @queues |> Map.new(fn q -> {q, []} end),
        recent_logins: [],
        heartbeats: %{},
        arrival_times: %{},
        remaining_capacity: 0,
        releases_per_tick: @releases_per_tick,
        use_queues: true,
        tick_timer_ref: tick_timer_ref
      }
      |> apply_server_capacity(telemetry_data)

    {:noreply, state}
  end

  @doc """
  If the queues are empty you get a {true, state} result
  If there is a queue you get a {false, state} result
  """
  @spec can_login?(pid(), T.userid(), map()) :: {map(), boolean()}
  def can_login?(pid, userid, state) do
    category = categorise_user(userid)

    cond do
      # They are exempt from capacity limits, we let them in right away!
      category == :instant ->
        new_state = accept_login(state, userid)
        {new_state, true}

      # state.remaining_capacity < 1 ->
      #   new_state = add_user_to_queue(state, category, {pid, userid})
      #   {new_state, false}

      # There is capacity, we let them in
      true ->
        new_state = add_user_to_queue(state, category, {pid, userid})
        {new_state, false}
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

  # This takes users out of the queue
  defp dequeue_users(state) do
    if state.remaining_capacity > 0 do
      now_ms = System.system_time(:millisecond)

      free_spots = min(state.remaining_capacity, state.releases_per_tick)

      released_users =
        @queues
        |> Enum.map(fn q ->
          state.queues[q]
        end)
        |> List.flatten()
        |> Enum.take(free_spots)
        |> Enum.filter(fn userid ->
          # If no arrival time, they've probably been here long enough
          wait_time = now_ms - Map.get(state.arrival_times, userid, 0)

          wait_time > @min_wait
        end)

      if Enum.empty?(released_users) do
        state
      else
        # Remove this user from heartbeats and queues
        new_queues =
          @queues
          |> Map.new(fn key ->
            existing_queue = Map.get(state.queues, key)

            new_queue =
              existing_queue
              |> Enum.reject(fn userid -> Enum.member?(released_users, userid) end)

            {key, new_queue}
          end)

        # credo:disable-for-next-line Credo.Check.Design.TagFIXME
        # FIXME: Waited for counter can be here with the now_ms value
        new_heartbeats = Map.drop(state.heartbeats, released_users)

        released_users
        |> Enum.each(fn userid ->
          {pid, _timestamp} = state.heartbeats[userid]
          send(pid, {:login_accepted, userid})
        end)

        new_arrival_times = Map.drop(state.arrival_times, released_users)

        PubSub.broadcast(
          Teiserver.PubSub,
          "teiserver_liveview_login_throttle",
          %{
            channel: "teiserver_liveview_login_throttle",
            event: :released_users,
            userids: released_users,
            new_arrival_times: new_arrival_times
          }
        )

        recent_login_timestamps =
          1..Enum.count(released_users)
          |> Enum.map(fn _ -> now_ms end)

        %{
          state
          | recent_logins: recent_login_timestamps ++ state.recent_logins,
            remaining_capacity: state.remaining_capacity - 1,
            queues: new_queues,
            heartbeats: new_heartbeats,
            arrival_times: new_arrival_times
        }
      end
    else
      state
    end
  end

  # When a login is accepted and we want to update certain metrics right away
  defp accept_login(
         %{recent_logins: recent_logins, remaining_capacity: remaining_capacity} = state,
         _userid
       ) do
    new_recent_logins = [System.system_time(:millisecond) | recent_logins]
    new_remaining_capacity = remaining_capacity - 1

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_liveview_login_throttle",
      %{
        channel: "teiserver_liveview_login_throttle",
        event: :accept_login,
        recent_logins: new_recent_logins,
        remaining_capacity: new_remaining_capacity
      }
    )

    %{
      state
      | recent_logins: new_recent_logins,
        remaining_capacity: new_remaining_capacity
    }
  end

  @spec categorise_user(T.userid()) :: atom
  defp categorise_user(userid) do
    user = Account.get_user_by_id(userid)

    cond do
      CacheUser.is_bot?(user) -> :instant
      CacheUser.has_any_role?(user, ["Server"]) -> :instant
      CacheUser.is_moderator?(user) -> :moderator
      CacheUser.has_any_role?(user, ["Core"]) -> :core
      CacheUser.has_any_role?(user, ["Contributor"]) -> :contributor
      CacheUser.has_any_role?(user, ["Overwatch", "Reviewer"]) -> :volunteer
      CacheUser.has_any_role?(user, ["VIP", "BAR+"]) -> :vip
      true -> :standard
    end
  end

  @spec apply_server_capacity(map(), map()) :: map()
  defp apply_server_capacity(state, telemetry_data) do
    total_limit = Config.get_site_config_cache("system.User limit")

    client_count =
      telemetry_data
      |> Map.get(:client, %{})
      |> Map.get(:total, 0)

    remaining_capacity = total_limit - client_count

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_liveview_login_throttle",
      %{
        channel: "teiserver_liveview_login_throttle",
        event: :updated_capacity,
        remaining_capacity: remaining_capacity
      }
    )

    %{state | remaining_capacity: remaining_capacity}
  end

  @spec start_link(list()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, [])
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
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
