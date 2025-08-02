defmodule Teiserver.Bridge.BridgeServer do
  @moduledoc """
  The server used to read events from Teiserver and then use the DiscordBridgeBot to send onwards
  """
  use GenServer
  alias Teiserver.{Account, Room, CacheUser}
  alias Teiserver.Chat.WordLib
  alias Phoenix.PubSub
  alias Teiserver.Config
  require Logger
  alias Teiserver.Data.Types, as: T
  alias Nostrum.Api

  def bot_name(), do: "DiscordBridgeBot"

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec get_bridge_userid() :: T.userid()
  def get_bridge_userid() do
    Teiserver.cache_get(:application_metadata_cache, "teiserver_bridge_userid")
  end

  @spec call_bridge(any()) :: any()
  def call_bridge(message) do
    bridge_pid = get_bridge_pid()
    GenServer.call(bridge_pid, message)
  end

  @spec cast_bridge(any()) :: :ok
  def cast_bridge(message) do
    bridge_pid = get_bridge_pid()
    GenServer.cast(bridge_pid, message)
  end

  @spec send_bridge(any()) :: :ok
  def send_bridge(message) do
    bridge_pid = get_bridge_pid()
    send(bridge_pid, message)
  end

  @spec send_direct_message(T.user_id(), String.t()) :: :ok | nil
  def send_direct_message(userid, message) do
    user = Account.get_user_by_id(userid)

    cond do
      user.discord_dm_channel && user.discord_dm_channel_id == nil ->
        nil

      true ->
        channel_id = user.discord_dm_channel_id || user.discord_dm_channel
        Api.Message.create(channel_id, message)
    end
  end

  @impl true
  def handle_call(:client_state, _from, state) do
    {:reply, state.client, state}
  end

  def handle_call({:lookup_room_from_channel, channel_id}, _from, state) do
    {:reply, state.room_lookup[channel_id], state}
  end

  @impl true
  def handle_cast({:update_client, new_client}, state) do
    {:noreply, %{state | client: new_client}}
  end

  def handle_cast({:merge_client, partial_client}, state) do
    {:noreply, %{state | client: Map.merge(state.client, partial_client)}}
  end

  # The bridge is ready to start doing stuff
  def handle_cast(:READY, state) do
    {:noreply, state}
  end

  @impl true
  def handle_info(:begin, _state) do
    state =
      if Teiserver.cache_get(:application_metadata_cache, "teiserver_full_startup_completed") !=
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

  # Teiserver.Bridge.BridgeServer.send_bridge(bridge_pid, :recache)
  def handle_info(:recache, state) do
    Logger.info("Recaching")
    {:noreply, build_local_caches(state)}
  end

  # Metrics
  def handle_info({:update_stats, stat_name, value}, state) do
    config_key =
      case stat_name do
        :client_count -> "teiserver.Discord counter clients"
        :player_count -> "teiserver.Discord counter players"
        :match_count -> "teiserver.Discord counter matches"
        :lobby_count -> "teiserver.Discord counter lobbies"
        _ -> ""
      end

    channel_id = Config.get_site_config_cache(config_key)

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
    user = Account.get_user_by_id(from_id)

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

      CacheUser.is_restricted?(user, ["Bridging"]) ->
        # Non-bridged user, ignore it
        nil

      Config.get_site_config_cache("teiserver.Bridge from server") == false ->
        nil

      WordLib.flagged_words(message) > 0 ->
        # In theory we should catch this at the general chat level but it's possible the user
        # won't have updated by the time the execution gets here so we need to be certain
        nil

      Map.has_key?(state.channel_lookup, room_name) ->
        message = if is_list(message), do: Enum.join(message, "\n"), else: message
        message = clean_message(message)

        room_name =
          if is_promo?(message) do
            "promote"
          else
            room_name
          end

        # If they are a bot they're only allowed to post to the promotion channel
        if CacheUser.is_bot?(user) do
          if room_name == "promote" do
            forward_to_discord(from_id, state.channel_lookup[room_name], message, state)
          end
        else
          forward_to_discord(from_id, state.channel_lookup[room_name], message, state)
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
    username = CacheUser.get_username(data.sender_id)

    CacheUser.send_direct_message(
      state.userid,
      data.sender_id,
      "I don't currently handle messages, sorry #{username}"
    )

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_client_messages:" <> _}, state), do: {:noreply, state}

  def handle_info(%{channel: "teiserver_server", event: :started}, state) do
    if Config.get_site_config_cache("teiserver.Bridge from server") do
      # Main
      channel_id = Config.get_site_config_cache("teiserver.Discord channel #main")

      if channel_id do
        Api.Message.create(channel_id, "Teiserver startup for node #{Teiserver.node_name()}")
      end

      # Server
      channel_id = Config.get_site_config_cache("teiserver.Discord channel #server-updates")

      if channel_id do
        Api.Message.create(channel_id, "Teiserver startup for node #{Teiserver.node_name()}")
      end
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server", event: :prep_stop}, state) do
    if Config.get_site_config_cache("teiserver.Bridge from server") do
      channel_id = Config.get_site_config_cache("teiserver.Discord channel #server-updates")

      if channel_id do
        Api.Message.create(channel_id, "Teiserver shutdown for node #{Teiserver.node_name()}")
      end
    end

    {:noreply, state}
  end

  def handle_info(%{channel: "teiserver_server"}, state), do: {:noreply, state}

  # pid = Teiserver.Bridge.BridgeServer.get_bridge_pid()
  # send(pid, :gdt_check)
  def handle_info(:gdt_check, state) do
    Api.Thread.list(Application.get_env(:teiserver, DiscordBridgeBot)[:guild_id])

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
    Teiserver.cache_put(:application_metadata_cache, "teiserver_bridge_userid", account.id)
    {:ok, user, client} = CacheUser.internal_client_login(account.id)

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      client: client,
      recent_bridged_messages: %{}
    }

    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_server")
    :ok = PubSub.subscribe(Teiserver.PubSub, "teiserver_client_messages:#{user.id}")

    build_local_caches(state)
  end

  defp build_local_caches(state) do
    channel_lookup =
      [
        "teiserver.Discord channel #main",
        "teiserver.Discord channel #newbies",
        "teiserver.Discord channel #promote",
        "teiserver.Discord channel #moderation-reports",
        "teiserver.Discord channel #moderation-actions",
        "teiserver.Discord channel #server-updates",
        "teiserver.Discord channel #telemetry-infologs",
        "teiserver.Discord forum #gdt-discussion",
        "teiserver.Discord forum #gdt-voting"
      ]
      |> Enum.map(fn key ->
        channel_id = Config.get_site_config_cache(key)

        if channel_id do
          [_, room] = String.split(key, "#")

          {room, channel_id}
        end
      end)
      |> Enum.reject(&(&1 == nil))
      |> Map.new()

    room_lookup =
      [
        "teiserver.Discord channel #main",
        "teiserver.Discord channel #newbies",
        "teiserver.Discord channel #promote"
      ]
      |> Enum.map(fn key ->
        channel_id = Config.get_site_config_cache(key)

        if channel_id do
          [_, room] = String.split(key, "#")

          {channel_id, room}
        end
      end)
      |> Enum.reject(&(&1 == nil))
      |> Map.new()

    Map.values(room_lookup)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, state.user.id)
      Room.add_user_to_room(state.user.id, room_name)

      :ok = PubSub.unsubscribe(Teiserver.PubSub, "room:#{room_name}")
      :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
    end)

    Teiserver.store_put(:application_metadata_cache, :discord_room_lookup, room_lookup)
    Teiserver.store_put(:application_metadata_cache, :discord_channel_lookup, channel_lookup)

    Map.merge(state, %{
      channel_lookup: channel_lookup,
      room_lookup: room_lookup
    })
  end

  defp forward_to_discord(from_id, channel, message, _state) do
    author = CacheUser.get_username(from_id)

    new_message =
      message
      |> convert_emoticons

    Api.Message.create(channel, "**#{author}**: #{new_message}")
  end

  defp convert_emoticons(message) do
    emoticon_map = Teiserver.Bridge.DiscordBridgeBot.get_text_to_emoticon_map()

    message
    |> String.replace(Map.keys(emoticon_map), fn text -> emoticon_map[text] end)
  end

  @spec get_bridge_account() :: Teiserver.Account.CacheUser.t()
  def get_bridge_account() do
    user =
      Account.get_user(nil,
        search: [
          email: "bridge@teiserver.local"
        ]
      )

    case user do
      nil ->
        # Make account
        {:ok, account} =
          Account.script_create_user(%{
            name: bot_name(),
            email: "bridge@teiserver.local",
            icon: "fa-brands fa-discord",
            colour: "#0066AA",
            password: Account.make_bot_password(),
            roles: ["Bot", "Verified"],
            data: %{
              bot: true,
              moderator: false,
              verified: true,
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

  @spec change_channel_name(String.t(), String.t()) :: boolean()
  def change_channel_name(_, ""), do: false
  def change_channel_name(nil, _), do: false
  def change_channel_name(0, _), do: false

  def change_channel_name(channel_id, new_name) do
    Api.Channel.modify(channel_id, %{
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
  @spec init(map()) :: {:ok, map()}
  def init(_opts) do
    if Teiserver.Communication.use_discord?() do
      send(self(), :begin)
    end

    Logger.metadata(request_id: "BridgeServer")
    Teiserver.cache_put(:application_metadata_cache, "teiserver_bridge_pid", self())

    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "BridgeServer",
      :bridge_server
    )

    {:ok, %{}}
  end

  @spec get_bridge_pid() :: pid
  defp get_bridge_pid() do
    Teiserver.cache_get(:application_metadata_cache, "teiserver_bridge_pid")
  end
end
