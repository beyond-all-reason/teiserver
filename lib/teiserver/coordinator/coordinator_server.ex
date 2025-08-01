defmodule Teiserver.Coordinator.CoordinatorServer do
  @moduledoc """
  The coordinator server is the interface point for the Coordinator system. Consuls are invisible (to the players) processes
  performing their actions in the name of the coordinator
  """
  use GenServer
  alias Teiserver.Config
  alias Teiserver.{Account, CacheUser, Clans, Room, Coordinator, Client, Moderation, Telemetry}
  alias Teiserver.Lobby
  alias Teiserver.Coordinator.{CoordinatorCommands}
  alias Phoenix.PubSub
  import Teiserver.Helper.TimexHelper, only: [date_to_str: 2]
  require Logger

  @dispute_string [
    "If you feel you have been the target of an erroneous or unjust moderation action please use the #open-ticket channel in our discord to appeal/dispute the action.",
    "Attempting to circumvent this moderation with a new account is not okay and can lead to suspension or banning."
  ]

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
    Teiserver.cache_put(:application_metadata_cache, "teiserver_coordinator_userid", account.id)

    {user, client} =
      case CacheUser.internal_client_login(account.id) do
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
      :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
    end)

    # Now join the clan channels
    Clans.list_clans()
    |> Enum.each(fn clan ->
      room_name = Room.clan_room_name(clan.tag)
      Room.get_or_make_room(room_name, user.id, clan.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_server")
    :ok = PubSub.subscribe(Teiserver.PubSub, "client_inout")
    :ok = PubSub.subscribe(Teiserver.PubSub, "legacy_user_updates:#{user.id}")

    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  # def handle_info({:new_message, userid, "coordinator", _message}, state) do
  #   # If it's us sending it, don't reply
  #   if userid != state.userid do
  #     username = CacheUser.get_username(userid)
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
        Client.clear_awaiting_warn_ack(userid)
        CacheUser.send_direct_message(state.userid, userid, "Thank you")

      _ ->
        user = CacheUser.get_user_by_id(userid)
        Logger.info("CoordinatorServer unhandled DM from #{user.name} of: #{message}")

        if not CacheUser.is_bot?(user) do
          CacheUser.send_direct_message(
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
    user = CacheUser.get_user_by_id(userid)

    if user do
      # Do we have a system welcome message?
      welcome_message = Config.get_site_config_cache("system.Login message")

      if welcome_message != "" do
        Coordinator.send_to_user(userid, welcome_message)
      end

      if Map.get(user, :lobby_client, nil) == "skylobby" do
        Coordinator.send_to_user(
          userid,
          "skylobby is not supported so is not benefiting from new features. Future server improvements are likely to break it; please instead use the official Chobby client available from our website - https://www.beyondallreason.info/download"
        )
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
              Enum.member?(action.restrictions, "Note") -> false
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

        if not Enum.empty?(reasons) do
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
              CacheUser.has_mute?(user) ->
                msg ++ @dispute_string

              has_warning ->
                Telemetry.log_simple_server_event(
                  user.id,
                  "has_warning.remove_user_from_any_lobby"
                )

                Lobby.remove_user_from_any_lobby(user.id)
                Client.set_awaiting_warn_ack(userid)

                acknowledge_prompt =
                  Config.get_site_config_cache("teiserver.Warning acknowledge prompt")

                msg ++ [@dispute_string, acknowledge_prompt]

              true ->
                msg ++ @dispute_string
            end

          Coordinator.send_to_user(userid, msg)
        end
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

  @spec get_coordinator_account() :: Teiserver.Account.CacheUser.t()
  def get_coordinator_account() do
    user =
      Account.get_user(nil,
        search: [
          email: "coordinator@teiserver.local"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.script_create_user(%{
            name: "Coordinator",
            email: "coordinator@teiserver.local",
            icon: "fa-solid fa-sitemap",
            colour: "#AA00AA",
            password: Account.make_bot_password(),
            roles: ["Bot", "Verified"],
            data: %{
              bot: true,
              moderator: true,
              lobby_client: "Teiserver Internal Process"
            }
          })

        Account.update_user_stat(account.id, %{
          country_override: Application.get_env(:teiserver, Teiserver)[:server_flag]
        })

        CacheUser.recache_user(account.id)
        account

      account ->
        account
    end
  end

  @impl true
  @spec init(map()) :: {:ok, map()}
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
