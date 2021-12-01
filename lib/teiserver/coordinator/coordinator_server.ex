defmodule Teiserver.Coordinator.CoordinatorServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Teiserver.{Account, User, Clans, Room, Coordinator}
  alias Teiserver.Coordinator.AutomodServer
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Coordinator coordinator")
    account = get_coordinator_account()
    ConCache.put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    user = case User.internal_client_login(account.id) do
      {:ok, user} -> user
      :error -> throw "No coordinator user found"
    end

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      queues: [],
      ready_queue_id: nil,
      consuls: %{}
    }

    ~w(main coordinator moderators)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    # Now join the clan channels
    Clans.list_clans()
    |> Enum.each(fn clan ->
      room_name = Room.clan_room_name(clan.tag)
      Room.get_or_make_room(room_name, user.id, clan.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_inout")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  # def handle_info({:new_message, userid, "coordinator", _message}, state) do
  #   # If it's us sending it, don't reply
  #   if userid != state.userid do
  #     username = User.get_username(userid)
  #     Room.send_message(state.userid, "coordinator", "I don't currently handle messages, sorry #{username}")
  #   end
  #   {:noreply, state}
  # end

  def handle_info({:new_message, _userid, _room_name, _message}, state) do
    {:noreply, state}
  end

  def handle_info({:direct_message, fromid, "$" <> command}, state) do
    from = User.get_user_by_id(fromid)

    new_state = case {command, from.moderator} do
      {"check " <> remaining, true} ->
        case User.get_userid(remaining) do
          nil ->
            User.send_direct_message(state.userid, fromid, "Unable to find a user with that name")
          userid ->
            result = AutomodServer.check_user(userid)
            User.send_direct_message(state.userid, fromid, "Automod result: #{result}")
        end
        state

      {"whois " <> remaining, true} ->
        case User.get_user_by_name(remaining) do
          nil ->
            User.send_direct_message(state.userid, fromid, "Unable to find a user with that name")
          user ->
            stats = Account.get_user_stat_data(user.id)

            player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
            spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
            rank_time = User.rank_time(user.id)

            msg = [
              "Found #{user.name}",
              "Rank: #{user.rank} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}"
            ]

            User.send_direct_message(state.userid, fromid, msg)
        end
        state

      {"whoami", _} ->
        stats = Account.get_user_stat_data(fromid)

        player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
        spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
        rank_time = User.rank_time(fromid)

        msg = [
          "You are #{from.name}",
          "Rank: #{from.rank} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}"
        ]

        User.send_direct_message(state.userid, fromid, msg)
        state

      _ ->
        username = User.get_username(fromid)
        User.send_direct_message(state.userid, fromid, "I don't currently handle messages, sorry #{username}")
        state
    end
    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, message}, state) do
    Logger.warn(message)

    username = User.get_username(userid)
    User.send_direct_message(state.userid, userid, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

  # Client inout
  def handle_info({:client_inout, :login, userid}, state) do
    user = User.get_user_by_id(userid)
    if User.is_warned?(user) or User.is_muted?(user) do
      reports = Account.list_reports(search: [
        target_id: userid,
        expired: false,
        filter: "closed"
      ])
      |> Enum.group_by(fn report ->
        report.response_action
      end)

      if User.is_warned?(user) do
        reasons = reports["Warn"]
        |> Enum.map(fn report -> " - " <> report.reason end)

        [_, expires] = user.warned
        if expires == nil do
          msg = ["This is a reminder that you received one or more formal warnings for misbehaving as listed below. This is your last warning and this warning does not expire." | reasons]
          Coordinator.send_to_user(userid, msg)
        else
          msg = ["This is a reminder that you recently received one or more formal warnings as listed below, the warnings expire #{expires}." | reasons]
          Coordinator.send_to_user(userid, msg)
        end
      end

      if User.is_muted?(user) do
        reasons = reports["Mute"]
        |> Enum.map(fn report -> " - " <> report.reason end)

        [_, expires] = user.muted
        if expires == nil do
          # They're perma muted, we don't really need to say anything else to them tbh
          nil
        else
          msg = ["This is a reminder that you are currently muted for reasons listed below, the muting will expire #{expires}." | reasons]
          Coordinator.send_to_user(userid, msg)
        end
      end
    end
    {:noreply, state}
  end
  def handle_info({:client_inout, :disconnect, _userid, _reason}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("Coordinator handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  @spec get_coordinator_account() :: Central.Account.User.t()
  def get_coordinator_account() do
    user = Account.get_user(nil, search: [
      exact_name: "Coordinator"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "Coordinator",
          email: "coordinator@teiserver",
          icon: "fa-solid fa-sitemap",
          colour: "#AA00AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: true,
            verified: true,
            lobby_client: "Teiserver Internal Process"
          }
        })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag],
        })

        Account.create_group_membership(%{
          user_id: account.id,
          group_id: Teiserver.internal_group_id()
        })

        User.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @spec make_password() :: String.t
  defp make_password() do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    ConCache.put(:teiserver_consul_pids, :coordinator, self())
    send(self(), :begin)
    {:ok, %{}}
  end
end
