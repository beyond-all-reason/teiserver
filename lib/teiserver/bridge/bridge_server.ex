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

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec get_bridge_userid() :: T.userid()
  def get_bridge_userid() do
    ConCache.get(:application_metadata_cache, "teiserver_bridge_userid")
  end

  @spec get_bridge_pid() :: pid
  def get_bridge_pid() do
    ConCache.get(:application_metadata_cache, "teiserver_bridge_pid")
  end

  def handle_info(:begin, _state) do
    state = if ConCache.get(:application_metadata_cache, "teiserver_full_startup_completed") != true do
      pid = self()
      spawn(fn ->
        :timer.sleep(1000)
        send(pid, :begin)
      end)
    else
      do_begin()
    end

    {:noreply, state}
  end

  # Metrics
  def handle_info({:update_stats, stat_name, value}, state) do
    channel_id = Application.get_env(:central, DiscordBridge)[:stat_channels]
      |> Map.get(stat_name, "")

    new_name = case stat_name do
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

  def handle_info({:new_message, _from_id, _room_name, "!" <> _message}, state), do: {:noreply, state}
  def handle_info({:new_message, _from_id, _room_name, "$" <> _message}, state), do: {:noreply, state}
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

        room_name = if String.contains?(message, " player(s) needed for battle"), do: "promote", else: room_name
        forward_to_discord(from_id, state.rooms[room_name], message, state)

      true ->
        nil
    end
    {:noreply, state}
  end

  def handle_info({:new_message_ex, from_id, room_name, message}, state) do
    handle_info({:new_message, from_id, room_name, message}, state)
  end

  def handle_info({:client_message, :received_direct_message, _userid, {from_id, _content}}, state) do
    username = User.get_username(from_id)
    User.send_direct_message(state.userid, from_id, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

  def handle_info({:client_message, _, _, _}, state), do: {:noreply, state}

  def handle_info({:application, :prep_stop}, state) do
    channels = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_, name} -> name == "server-updates" end)

    case channels do
      [{channel_id, _}] ->
        Alchemy.Client.send_message(
          channel_id,
          "Teiserver shutdown for node #{Node.self()}",
          []# Options
        )
      _ ->
        :ok
    end

    {:noreply, state}
  end

  def handle_info({:application, _}, state), do: {:noreply, state}

  # Catchall handle_info
  def handle_info(msg, state) do
    Logger.error("BridgeServer handle_info error. No handler for msg of #{Kernel.inspect msg}")
    {:noreply, state}
  end

  defp do_begin() do
    Logger.debug("Starting up Bridge server")
    account = get_bridge_account()
    ConCache.put(:application_metadata_cache, "teiserver_bridge_userid", account.id)
    {:ok, user} = User.internal_client_login(account.id)

    rooms = Application.get_env(:central, DiscordBridge)[:bridges]
    |> Map.new(fn {chan, room} -> {room, chan} end)
    |> Map.drop(["moderation-reports", "moderation-actions"])

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      lobby_host: false,
      user: user,
      rooms: rooms
    }

    Map.keys(rooms)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    # Startup message
    channels = Application.get_env(:central, DiscordBridge)[:bridges]
      |> Enum.filter(fn {_, name} -> name == "server-updates" end)

    node_start_time = Central.cache_get(:application_metadata_cache, :node_startup_datetime)
    diff_ms = Timex.diff(Timex.now(), node_start_time, :milliseconds)

    case channels do
      [{channel_id, _}] ->
        Alchemy.Client.send_message(
          channel_id,
          "Teiserver startup for node #{Node.self()} in #{diff_ms}ms",
          []# Options
        )
      _ ->
        :ok
    end

    :ok = PubSub.subscribe(Central.PubSub, "application")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")

    state
  end

  defp forward_to_discord(from_id, channel, message, _state) do
    author = User.get_username(from_id)

    new_message = message
      |> convert_emoticons

    Alchemy.Client.send_message(
      channel,
      "**#{author}**: #{new_message}",
      []# Options
    )
  end

  defp convert_emoticons(message) do
    emoticon_map = Teiserver.Bridge.DiscordBridge.get_text_to_emoticon_map()

    message
    |> String.replace(Map.keys(emoticon_map), fn text -> emoticon_map[text] end)
  end

  @spec get_bridge_account() :: Central.Account.User.t()
  def get_bridge_account() do
    user = Account.get_user(nil, search: [
      email: "bridge@teiserver"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "DiscordBridge",
          email: "bridge@teiserver",
          icon: "fa-brands fa-discord",
          colour: "#0066AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: false,
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

  @spec change_channel_name(String.t(), String.t()) :: boolean()
  def change_channel_name(_, ""), do: false
  def change_channel_name("", _), do: false
  def change_channel_name(channel_id, new_name) do
    case Alchemy.Client.get_channel(channel_id) do
      {:ok, _channel} ->
        Alchemy.Client.edit_channel(channel_id, name: new_name)
      _ ->
        false
    end
  end

  @spec make_password() :: String.t
  defp make_password() do
    :crypto.strong_rand_bytes(64) |> Base.encode64(padding: false) |> binary_part(0, 64)
  end

  defp clean_message(message) do
    message
    |> String.replace("@", " at ")
  end

  defp message_contains?(messages, contains) when is_list(messages) do
    messages
    |> Enum.filter(fn m -> String.contains?(m, contains) end)
    |> Enum.any?
  end
  defp message_contains?(message, contains), do: String.contains?(message, contains)

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(_opts) do
    if Application.get_env(:central, Teiserver)[:enable_discord_bridge] do
      send(self(), :begin)
    end
    ConCache.put(:application_metadata_cache, "teiserver_bridge_pid", self())
    Horde.Registry.register(
      Teiserver.ServerRegistry,
      "BridgeServer",
      :bridge_server
    )

    {:ok, %{}}
  end
end
