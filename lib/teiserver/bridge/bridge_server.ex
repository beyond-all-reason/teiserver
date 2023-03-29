defmodule Teiserver.Bridge.BridgeServer do
  @moduledoc """
  The server used to read events from Teiserver and then use the DiscordBridge to send onwards
  """
  use GenServer
  alias Teiserver.{Account, Room, User}
  alias Teiserver.Chat.WordLib
  alias Phoenix.PubSub
  alias Central.Config
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Nostrum.Api

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec get_bridge_userid() :: T.userid()
  def get_bridge_userid() do
    Central.cache_get(:application_metadata_cache, "teiserver_bridge_userid")
  end

  @spec get_bridge_pid() :: pid
  def get_bridge_pid() do
    Central.cache_get(:application_metadata_cache, "teiserver_bridge_pid")
  end

  @spec send_direct_message(T.user_id(), String.t()) :: :ok | nil
  def send_direct_message(userid, message) do
    user = User.get_user_by_id(userid)

    cond do
      user.discord_dm_channel == nil ->
        nil

      true ->
        channel_id = user.discord_dm_channel
        Api.create_message(channel_id, message)
    end
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
    state =
      if Central.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") !=
           true do
        pid = self()

        spawn(fn ->
          :timer.sleep(250)
          send(pid, :begin)
        end)
      else
        do_begin()
      end

    {:noreply, state}
  end

  # Metrics
  def handle_info({:update_stats, stat_name, value}, state) do
    channel_id =
      Application.get_env(:central, DiscordBridge)[:stat_channels]
      |> Map.get(stat_name, "")

    new_name =
      case stat_name do
        :client_count -> "Players online: #{value}"
        :player_count -> "Players in game: #{value}"
        :match_count -> "Ongoing battles: #{value}"
        :lobby_count -> "Open lobbies: #{value}"
        _ -> ""
      end

    change_channel_name(channel_id, new_name)

    {:noreply, state}
  end

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, _from_id, _room_name, "!" <> _message}, state),
    do: {:noreply, state}

  def handle_info({:new_message, _from_id, _room_name, "$" <> _message}, state),
    do: {:noreply, state}

  def handle_info({:new_message, from_id, room_name, message}, state) do
    user = User.get_user_by_id(from_id)

    cond do
      from_id == state.userid ->
        # It's us, ignore it
        nil

      message_contains?(message, "http:") ->
        nil

      message_contains?(message, "https:") ->
        nil

      message_starts_with?(message, "/") ->
        nil

      User.is_restricted?(user, ["Bridging"]) ->
        # Non-bridged user, ignore it
        nil

      Config.get_site_config_cache("teiserver.Bridge from server") == false ->
        nil

      WordLib.flagged_words(message) > 0 ->
        # In theory we should catch this at the general chat level but it's possible the user
        # won't have updated by the time the execution gets here so we need to be certain
        nil

      Map.has_key?(state.rooms, room_name) ->
        message = if is_list(message), do: Enum.join(message, "\n"), else: message
        message = clean_message(message)

        room_name =
          if is_promo?(message) do
            "promote"
          else
            room_name
          end

        # If they are a bot they're only allowed to post to the promotion channel
        if User.is_bot?(user) do
          if room_name == "promote" do
            forward_to_discord(from_id, state.rooms[room_name], message, state)
          end
        else
          forward_to_discord(from_id, state.rooms[room_name], message, state)
        end

      true ->
        nil
    end

    {:noreply, state}
  end

  def handle_info({:new_message_ex, from_id, room_name, message}, state) do
    handle_info({:new_message, from_id, room_name, message}, state)
  end

  def handle_info(
        data = %{channel: "teiserver_client_messages:" <> _, event: :received_direct_message},
        state
      ) do
    username = User.get_username(data.sender_id)

    User.send_direct_message(
      state.userid,
      data.sender_id,
      "I don't currently handle messages, sorry #{username}"
    )

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, state), do: {:noreply, state}

  def handle_info(%{channel: "teiserver_server", event: :started}, state) do
    channels =
      Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_, name} -> name == "server-updates" end)

    case channels do
      [{channel_id, _}] ->
        Api.create_message(channel_id, "Teiserver startup for node #{Teiserver.node_name()}")

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server", event: :prep_stop}, state) do
    channels =
      Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_, name} -> name == "server-updates" end)

    case channels do
      [{channel_id, _}] ->
        Api.create_message(channel_id, "Teiserver shutdown for node #{Teiserver.node_name()}")

      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state), do: {:noreply, state}

  # pid = Teiserver.Bridge.BridgeServer.get_bridge_pid()
  # send(pid, :gdt_check)
  def handle_info(:gdt_check, state) do
    Api.list_guild_threads(Application.get_env(:central, DiscordBridge)[:guild_id])

    # Api.list_joined_private_archived_threads(channel_id)
    # When a thread in 👇｜game-design-team has gone 48 hours without any new messages:
    # 1. Lock the thread
    # 2. Create a thread in ☝｜game-design-voting with the same name and (Vote) appended to the end
    # 3. In the first message of the thread, ping the Admins and Game Design Team roles, and if possible, copy the content of the first post in the original thread

    # When a thread in ☝｜game-design-voting has gone 48 hours without any new messages:
    # 1. Create a poll for the members of the GDC to vote on, with the options being Accept and Reject, since making context aware voting options is probably too complicated
    # 2. Ping the Game Design Team role to vote
    # For threads in 💡｜suggestions , we haven't agreed on a process yet, which we'll need to do before we can get a bot to do what we want

    # # Currently having an issue where I can't get the ID for the emoji
    # # luckily we can just put the emjoi character in and it should work
    # Nostrum.Api.create_reaction(thread.id, message.id, "👍")
    # Nostrum.Api.create_reaction(thread.id, message.id, "👎")
    # Nostrum.Api.create_reaction(thread.id, message.id, "👐")

    {:noreply, state}
  end

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("BridgeServer handle_info error. No handler for msg of #{Kernel.inspect(msg)}")
    {:noreply, state}
  end

  defp is_promo?(message) do
    regexes =
      [
        Regex.run(~r/\+\d+( more|needed)?$/, message),
        Regex.run(~r/\d+ more needed$/, message),
        Regex.run(~r/\d+\+? (more )?for \d(v|vs)\d/, message),
        Regex.run(~r/(more|needed) for \d(v|vs)\d/, message),
        Regex.run(~r/\d needed/, message)
      ]
      |> Enum.reject(&(&1 == nil))

    cond do
      String.contains?(message, " player(s) needed for battle") -> true
      not Enum.empty?(regexes) -> true
      true -> false
    end
  end

  defp do_begin() do
    Logger.debug("Starting up Bridge server")
    account = get_bridge_account()
    Central.cache_put(:application_metadata_cache, "teiserver_bridge_userid", account.id)
    {:ok, user, client} = User.internal_client_login(account.id)

    rooms =
      Application.get_env(:central, DiscordBridge)[:bridges]
      |> Map.new(fn {chan, room} -> {room, chan} end)
      |> Map.drop(["moderation-reports", "moderation-actions"])

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      rooms: rooms,
      client: client
    }

    Map.keys(rooms)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    :ok = PubSub.subscribe(Central.PubSub, "teiserver_server")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")

    state
  end

  defp forward_to_discord(from_id, channel, message, _state) do
    author = User.get_username(from_id)

    new_message =
      message
      |> convert_emoticons

    Api.create_message(channel, "**#{author}**: #{new_message}")
  end

  defp convert_emoticons(message) do
    emoticon_map = Teiserver.Bridge.DiscordBridge.get_text_to_emoticon_map()

    message
    |> String.replace(Map.keys(emoticon_map), fn text -> emoticon_map[text] end)
  end

  @spec get_bridge_account() :: Central.Account.User.t()
  def get_bridge_account() do
    user =
      Account.get_user(nil,
        search: [
          email: "bridge@teiserver"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.create_user(%{
            name: "DiscordBridge",
            email: "bridge@teiserver",
            icon: "fa-brands fa-discord",
            colour: "#0066AA",
            admin_group_id: Teiserver.internal_group_id(),
            password: Account.make_bot_password(),
            data: %{
              bot: true,
              moderator: false,
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

  @spec change_channel_name(String.t(), String.t()) :: boolean()
  def change_channel_name(_, ""), do: false
  def change_channel_name("", _), do: false

  def change_channel_name(channel_id, new_name) do
    Api.modify_channel(channel_id, %{
      name: new_name
    })

    false
  end

  defp clean_message(message) do
    message
    |> String.replace("@", " at ")
  end

  defp message_contains?(messages, contains) when is_list(messages) do
    messages
    |> Enum.filter(fn m -> String.contains?(m, contains) end)
    |> Enum.any?()
  end

  defp message_contains?(message, contains), do: String.contains?(message, contains)

  defp message_starts_with?(messages, text) when is_list(messages) do
    messages
    |> Enum.filter(fn m -> String.starts_with?(m, text) end)
    |> Enum.any?()
  end

  defp message_starts_with?(message, text), do: String.starts_with?(message, text)

  @impl true
  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    if Application.get_env(:central, Teiserver)[:enable_discord_bridge] do
      send(self(), :begin)
    end

    Central.cache_put(:application_metadata_cache, "teiserver_bridge_pid", self())

    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "BridgeServer",
      :bridge_server
    )

    {:ok, %{}}
  end
end
