defmodule Teiserver.Coordinator.CoordinatorServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Central.Config
  alias Teiserver.{Account, User, Clans, Room, Coordinator, Client}
  alias Teiserver.Coordinator.{CoordinatorCommands}
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_info(:begin, _state) do
    Logger.debug("Starting up Coordinator main server")
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

  def handle_info({:new_message, _userid, _room_name, _message}, state), do: {:noreply, state}
  def handle_info({:new_message_ex, _userid, _room_name, _message}, state), do: {:noreply, state}

  def handle_info({:direct_message, sender_id, "$" <> command}, state) do
    cmd = Coordinator.Parser.parse_command(sender_id, "$#{command}")
    new_state = CoordinatorCommands.handle_command(cmd, state)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, message}, state) do
    warning_response = Config.get_site_config_cache("teiserver.Warning acknowledge response")
      |> String.downcase
      |> String.trim

    converted_message = message
      |> String.downcase
      |> String.trim

    case converted_message do
      ^warning_response ->
        client = Client.get_client_by_id(userid)

        last_login = Account.get_user_stat_data(userid)
        |> Map.get("last_login")

        time_diff = :erlang.system_time(:seconds) - last_login
        Logger.info("Acknowledge time of #{time_diff} seconds for #{userid}:#{client.name}")

        Client.clear_awaiting_warn_ack(userid)
        User.send_direct_message(state.userid, userid, "Thank you")
      _ ->
        username = User.get_username(userid)
        User.send_direct_message(state.userid, userid, "I don't currently handle messages, sorry #{username}")
    end
    {:noreply, state}
  end

  # Client inout
  def handle_info({:client_inout, :login, userid}, state) do
    :timer.send_after(500, {:do_client_inout, :login, userid})
    {:noreply, state}
  end

  def handle_info({:do_client_inout, :login, userid}, state) do
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

        # Coordinator message:
        # You have been [Warned/Banned/Muted/Restricted] by [Admin]
        # Reason: [Reason]
        # Restriction(s): [restriction type], [restriction type2] etc  *(if applied)*
        # Expires: [Time]
        # If the behaviour continues, a [follow-up action] will be employed.

        dispute_string = "If you feel that you have been the target of an erroneous or unjust moderation action please contact the moderator who performed the action or our head of moderation - Beherith"

        msg = if expires == nil do
          ["This is a reminder that you received one or more formal warnings for misbehaving as listed below. This is your last warning and this warning does not expire."] ++ reasons
        else
          expires = String.replace(expires, "T", " ")
          ["This is a reminder that you recently received one or more formal warnings as listed below, the warnings expire #{expires}."] ++ reasons
        end

        # Follow-up
        followups = reports["Warn"]
        |> Enum.filter(fn r -> r.followup != nil and r.followup != "" end)
        |> Enum.map(fn r -> "- #{r.followup}" end)

        msg = if Enum.empty?(followups) do
          msg
        else
          msg ++ ["If the behaviour continues one or more of the following actions may be performed:"] ++ followups
        end

        # Do we need an acknowledgement? If they are muted then no.
        msg = if User.is_muted?(user) do
          msg ++ [dispute_string]
        else
          Client.set_awaiting_warn_ack(userid)
          acknowledge_prompt = Config.get_site_config_cache("teiserver.Warning acknowledge prompt")
          msg ++ [dispute_string, acknowledge_prompt]
        end

        Coordinator.send_to_user(userid, msg)
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
    Logger.error("Coordinator server handle_info error. No handler for msg of #{Kernel.inspect msg}")
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
