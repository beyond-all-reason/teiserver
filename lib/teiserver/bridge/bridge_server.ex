defmodule Teiserver.Bridge.BridgeServer do
  @moduledoc """
  The server used to read events from Teiserver and then use the DiscordBridge to send onwards
  """
  use GenServer
  alias Teiserver.{Account, Room, User}
  alias Phoenix.PubSub
  require Logger

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  @spec get_bridge_userid() :: T.userid()
  def get_bridge_userid() do
    ConCache.get(:application_metadata_cache, "teiserver_bridge_userid")
  end

  def handle_info(:begin, _state) do
    state = if ConCache.get(:application_metadata_cache, "teiserver_startup_completed") != true do
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

  # Direct/Room messaging
  def handle_info({:add_user_to_room, _userid, _room_name}, state), do: {:noreply, state}
  def handle_info({:remove_user_from_room, _userid, _room_name}, state), do: {:noreply, state}

  def handle_info({:new_message, from_id, room_name, message}, state) do
    room_name = if String.contains?(message, " player(s) needed for battle "), do: "promote", else: room_name

    cond do
      from_id == state.userid ->
        # It's us, ignore it
        nil

      Map.has_key?(state.rooms, room_name) ->
        forward_to_discord(from_id, state.rooms[room_name], message)

      true ->
        nil
    end
    {:noreply, state}
  end

  def handle_info({:new_message_ex, from_id, room_name, message}, state) do
    handle_info({:new_message, from_id, room_name, message}, state)
  end

  def handle_info({:direct_message, userid, _message}, state) do
    username = User.get_username(userid)
    User.send_direct_message(state.userid, userid, "I don't currently handle messages, sorry #{username}")
    {:noreply, state}
  end

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

    state = %{
      ip: "127.0.0.1",
      userid: user.id,
      username: user.name,
      battle_host: false,
      user: user,
      rooms: rooms
    }

    Map.keys(rooms)
    |> Enum.each(fn room_name ->
      Room.get_or_make_room(room_name, user.id)
      Room.add_user_to_room(user.id, room_name)
      :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")
    end)

    state
  end

  defp forward_to_discord(from_id, channel, message) do
    Logger.debug("forwarding")
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
      exact_name: "Bridge"
    ])

    case user do
      nil ->
        # Make account
        {:ok, account} = Account.create_user(%{
          name: "Bridge",
          email: "bridge@teiserver",
          icon: "fa-brand fa-discord",
          colour: "#0066AA",
          admin_group_id: Teiserver.internal_group_id(),
          password: make_password(),
          data: %{
            bot: true,
            moderator: false,
            verified: true,
            country_override: "GB",# TODO: Make this configurable
            lobbyid: "Teiserver Internal Process"
          }
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
    if Application.get_env(:central, Teiserver)[:enable_discord_bridge] do
      send(self(), :begin)
    end

    {:ok, %{}}
  end
end
