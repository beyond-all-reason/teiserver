defmodule Teiserver.Coordinator.CoordinatorServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Central.Config
  alias Teiserver.{Account, User, Clans, Room, Coordinator, Client, Moderation}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Coordinator.{CoordinatorCommands}
  alias Phoenix.PubSub
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]
  require Logger

  @dispute_string "If you feel you have been the target of an erroneous or unjust moderation action please contact the head of moderation, Beherith"

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @impl true
  def handle_call(:client_state, _from, state) do
    {:reply, state.client, state}
  end

  @impl true
  def handle_cast({:update_client, new_client}, state) do
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_client, partial_client}, state) do
    {:noreply, %{state | client: Map.merge(state.client, partial_client)}}
  end

  @impl true
  def handle_info(:begin, _state) do
    Logger.debug("Starting up Coordinator main server")
    account = get_coordinator_account()
    Central.cache_put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    {user, client} =
      case User.internal_client_login(account.id) do
        {:ok, user, client} -> {user, client}
        :error -> raise "No coordinator user found"
      end

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      queues: [],
      ready_queue_id: nil,
      client: client,
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

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")
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

  def handle_info({:consul_command, cmd}, state) do
    new_state = CoordinatorCommands.handle_command(cmd, state)
    {:noreply, new_state}
  end

  def handle_info({:direct_message, from_id, parts}, state) when is_list(parts) do
    new_state =
      parts
      |> Enum.reduce(state, fn part, acc_state ->
        {_, new_state} = handle_info({:direct_message, from_id, part}, acc_state)
        new_state
      end)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, sender_id, "$" <> command}, state) do
    cmd = Coordinator.Parser.parse_command(sender_id, "$#{command}")
    new_state = CoordinatorCommands.handle_command(cmd, state)

    {:noreply, new_state}
  end

  def handle_info({:direct_message, userid, "hello"}, state) do
    case Client.get_client_by_id(userid) do
      nil ->
        :ok

      %{lobby_id: nil} ->
        :ok

      %{lobby_id: lobby_id} ->
        Coordinator.cast_consul(lobby_id, {:hello_message, userid})
        Coordinator.send_to_user(userid, "Thank you, you've been marked as present.")

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:direct_message, userid, message}, state) do
    warning_response =
      Config.get_site_config_cache("teiserver.Warning acknowledge response")
      |> String.downcase()
      |> String.trim()

    converted_message =
      message
      |> String.downcase()
      |> String.trim()

    case converted_message do
      ^warning_response ->
        client = Client.get_client_by_id(userid)

        last_login =
          Account.get_user_stat_data(userid)
          |> Map.get("last_login")

        time_diff = System.system_time(:second) - last_login
        Logger.info("Acknowledge time of #{time_diff} seconds for #{userid}:#{client.name}")

        Client.clear_awaiting_warn_ack(userid)
        User.send_direct_message(state.userid, userid, "Thank you")

      _ ->
        user = User.get_user_by_id(userid)
        Logger.info("CoordinatorServer unhandled DM from #{user.name} of: #{message}")

        if not User.is_bot?(user) do
          User.send_direct_message(
            state.userid,
            userid,
            "I don't currently handle messages, sorry #{user.name}"
          )
        end
    end

    {:noreply, state}
  end

  # Application start/stop
  def handle_info(%{channel: "teiserver_server", event: :prep_stop}, state) do
    Room.send_message(
      state.userid,
      "main",
      "Teiserver update taking place, game rooms will reappear after the update has taken place."
    )

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state) do
    {:noreply, state}
  end

  # Client inout
  def handle_info(%{channel: "client_inout", event: :login, userid: userid}, state) do
    delay = Config.get_site_config_cache("teiserver.Post login action delay")
    :timer.send_after(delay, {:do_client_inout, :login, userid})

    {:noreply, state}
  end

  def handle_info(%{channel: "client_inout", event: :disconnect, userid: userid}, state) do
    Teiserver.Account.RecacheUserStatsTask.disconnected(userid)

    {:noreply, state}
  end

  def handle_info(%{channel: "client_inout"}, state), do: {:noreply, state}

  def handle_info({:do_client_inout, :login, userid}, state) do
    user = User.get_user_by_id(userid)

    if user do
      # FIXME: Remove this after a few weeks
      if user.lobby_client == "skylobby" do
        Coordinator.send_to_user(
          userid,
          "Dear skylobby user, if you don't configure your lobby to use the BAR CDN " <>
            "you might soon experience issues with downloading versions of the BAR game " <>
            "required for the online play. Please do so by following " <>
            "https://gist.github.com/p2004a/659e97cce92f8106355e011c6a7aad96"
        )
      end

      # Do we have a system welcome message?
      welcome_message = Config.get_site_config_cache("system.Login message")

      if welcome_message != "" do
        Coordinator.send_to_user(userid, welcome_message)
      end

      relevant_restrictions =
        user.restrictions
        |> Enum.filter(fn r -> not Enum.member?(["Bridging"], r) end)

      if not Enum.empty?(relevant_restrictions) do
        actions =
          Moderation.list_actions(
            search: [
              target_id: userid,
              expiry: "Unexpired only"
            ]
          )

        # Reasons you've had action taken against you
        reasons =
          actions
          |> Enum.filter(fn action ->
            cond do
              Enum.member?(action.restrictions, "Bridging") -> false
              true -> true
            end
          end)
          |> Enum.map(fn action ->
            expires =
              if action.expires do
                ", expires #{date_to_str(action.expires, format: :ymd_hms)}"
              else
                ""
              end

            " - #{action.reason}#{expires}"
          end)

        msg =
          [
            "This is a reminder that you received one or more formal moderation actions as listed below:"
          ] ++ reasons

        has_warning =
          actions
          |> Enum.map(fn a -> a.restrictions end)
          |> List.flatten()
          |> Enum.member?("Warning reminder")

        # Do we need an acknowledgement? If they are muted then no.
        msg =
          cond do
            User.has_mute?(user) ->
              msg ++ [@dispute_string]

            has_warning ->
              Lobby.remove_user_from_any_lobby(user.id)
              Client.set_awaiting_warn_ack(userid)

              acknowledge_prompt =
                Config.get_site_config_cache("teiserver.Warning acknowledge prompt")

              msg ++ [@dispute_string, acknowledge_prompt]

            true ->
              msg ++ [@dispute_string]
          end

        Coordinator.send_to_user(userid, msg)
      end
    end

    {:noreply, state}
  end

  # Special debugging to see what is being sent
  def handle_info({:timeout, duration}, state) do
    :timer.sleep(duration)
    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error(
      "CoordinatorServer handle_info error. No handler for msg of #{Kernel.inspect(msg)}"
    )

    {:noreply, state}
  end

  @spec get_coordinator_account() :: Central.Account.User.t()
  def get_coordinator_account() do
    user =
      Account.get_user(nil,
        search: [
          email: "coordinator@teiserver"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.create_user(%{
            name: "Coordinator",
            email: "coordinator@teiserver",
            icon: "fa-solid fa-sitemap",
            colour: "#AA00AA",
            admin_group_id: Teiserver.internal_group_id(),
            password: Account.make_bot_password(),
            data: %{
              bot: true,
              moderator: true,
              verified: true,
              lobby_client: "Teiserver Internal Process"
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:central, Teiserver)[:server_flag]
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

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "CoordinatorServer",
      :coordinator
    )

    send(self(), :begin)
    {:ok, %{client: %{}}}
  end
end
