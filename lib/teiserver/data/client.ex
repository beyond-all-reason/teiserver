# defmodule Teiserver.Data.ClientStruct do
#   @enforce_keys [:in_game, :away, :rank, :moderator, :bot]
#   defstruct [
#     :id, :name, :team_size, :icon, :colour, :settings, :conditions, :map_list,
#     current_search_time: 0, current_size: 0, contents: [], pid: nil
#   ]
# end

defmodule Teiserver.Client do
  @moduledoc false
  alias Phoenix.PubSub
  alias Teiserver.{Room, User, Coordinator, Account, Telemetry}
  alias Teiserver.Battle.Lobby
  alias Central.Helpers.TimexHelper
  require Logger

  alias Teiserver.Data.Types, as: T

  @chat_flood_count_short 3
  @chat_flood_time_short 1
  @chat_flood_count_long 10
  @chat_flood_time_long 5
  @temp_mute_count_limit 3

  @spec create(Map.t()) :: Map.t()
  def create(client) do
    Map.merge(
      %{
        in_game: false,
        away: false,
        rank: 1,
        moderator: false,
        bot: false,

        # Battle stuff
        ready: false,
        team_number: 0,# Used for archon mode
        team_colour: 0,
        ally_team_number: 0,# Actual which team the player is on
        player: false,
        handicap: 0,
        sync: 0,
        side: 0,

        # TODO: Change client:lobby_id to be client:battle_lobby_id
        lobby_id: nil,
        current_lobby_id: nil,
        print_client_messages: false,
        print_server_messages: false,
        chat_times: [],
        temp_mute_count: 0,
        ip: nil,
        country: nil,
        lobby_client: nil,

        shadowbanned: false,
        awaiting_warn_ack: false,
        warned: false,
        muted: false,
        restricted: false
      },
      client
    )
  end

  @spec reset_battlestatus(Map.t()) :: Map.t()
  def reset_battlestatus(client) do
    %{client |
      team_number: 0,
      ally_team_number: 0,
      player: false,
      handicap: 0,
      sync: 0,
      lobby_id: nil,
      current_lobby_id: nil
    }
  end

  def login(user, pid, ip \\ nil) do
    stats = Account.get_user_stat_data(user.id)

    client =
      create(%{
        userid: user.id,
        name: user.name,
        pid: pid,
        rank: user.rank,
        moderator: User.is_moderator?(user),
        bot: User.is_bot?(user),
        away: false,
        in_game: false,
        ip: ip || stats["last_ip"],
        country: stats["country"] || "??",
        lobby_client: stats["lobby_client"],

        shadowbanned: User.is_shadowbanned?(user),
        muted: User.has_mute?(user),
        awaiting_warn_ack: false,
        warned: false
      })
      |> add_client

    PubSub.broadcast(
      Central.PubSub,
      "legacy_all_user_updates",
      {:user_logged_in, user.id}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_inout",
      {:client_inout, :login, user.id}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_action_updates:#{user.id}",
      {:client_action, :client_connect, user.id}
    )

    # Message logging
    if user.print_client_messages do
      enable_client_message_print(user.id)
    end

    if user.print_server_messages do
      enable_server_message_print(user.id)
    end

    # Lets give everything a chance to propagate
    :timer.sleep(Application.get_env(:central, Teiserver)[:post_login_delay])

    Logger.info("Client connected: #{client.name} using #{client.lobby_client}")

    if client.bot do
      Telemetry.increment(:bots_connected)
    else
      Telemetry.increment(:users_connected)
    end

    client
  end

  @spec update(Map.t(), :silent | :client_updated_status | :client_updated_battlestatus) :: Map.t()
  def update(%{userid: _} = client, reason) do
    client =
      client
      |> add_client

    if reason != :silent do
      PubSub.broadcast(Central.PubSub, "legacy_all_client_updates", {:updated_client, client, reason})

      if client.lobby_id do
        PubSub.broadcast(
          Central.PubSub,
          "teiserver_lobby_updates:#{client.lobby_id}",
          {:lobby_update, :updated_client_battlestatus, client.lobby_id, {client, reason}}
        )
      end
    end

    client
  end
  def update(client, _reason), do: client

  @spec join_battle(T.client_id(), Integer.t(), Integer.t()) :: nil | Map.t()
  def join_battle(userid, lobby_id, colour \\ 0) do
    case get_client_by_id(userid) do
      nil ->
        nil

      client ->
        new_client = reset_battlestatus(client)
        new_client = %{new_client | team_colour: colour, lobby_id: lobby_id}
        Central.cache_put(:clients, new_client.userid, new_client)
        new_client
    end
  end

  @spec leave_battle(Integer.t() | nil) :: Map.t() | nil
  def leave_battle(nil), do: nil

  def leave_battle(userid) do
    case get_client_by_id(userid) do
      nil ->
        nil

      %{lobby_id: nil} = client ->
        client

      client ->
        new_client = reset_battlestatus(client)
        Central.cache_put(:clients, new_client.userid, new_client)
        new_client
    end
  end

  @spec leave_rooms(Integer.t()) :: List.t()
  def leave_rooms(userid) do
    Room.list_rooms()
    |> Enum.each(fn room ->
      if userid in room.members do
        Room.remove_user_from_room(userid, room.name)
      end
    end)
  end

  @spec get_client_by_name(nil) :: nil
  @spec get_client_by_name(String.t()) :: nil | Map.t()
  def get_client_by_name(nil), do: nil
  def get_client_by_name(""), do: nil

  def get_client_by_name(name) do
    userid = User.get_userid(name)
    Central.cache_get(:clients, userid)
  end

  @spec get_client_by_id(Integer.t() | nil) :: nil | Map.t()
  def get_client_by_id(nil), do: nil

  def get_client_by_id(userid) do
    Central.cache_get(:clients, userid)
  end

  def get_client_by_pid(pid) do
    list_clients()
    |> Enum.filter(fn client ->
      client.pid == pid
    end)
  end

  @spec get_clients(List.t()) :: List.t()
  def get_clients([]), do: []

  def get_clients(id_list) do
    id_list
    |> Enum.map(fn userid -> Central.cache_get(:clients, userid) end)
  end

  @spec add_client(Map.t()) :: Map.t()
  def add_client(client) do
    Central.cache_put(:clients, client.userid, client)

    Central.cache_update(:lists, :clients, fn value ->
      new_value =
        ([client.userid | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    client
  end

  @spec list_client_ids() :: [integer()]
  def list_client_ids() do
    case Central.cache_get(:lists, :clients) do
      nil -> []
      ids -> ids
    end
  end

  @spec list_clients() :: [Map.t()]
  def list_clients() do
    list_client_ids()
    |> list_clients()
  end

  @spec list_clients([integer()]) :: [Map.t()]
  def list_clients(id_list) do
    id_list
    |> Enum.map(fn c -> get_client_by_id(c) end)
  end

  @spec refresh_client(T.userid()) :: Map.t()
  def refresh_client(userid) do
    user = User.get_user_by_id(userid)
    stats = Account.get_user_stat_data(user.id)

    client = get_client_by_id(userid)
    %{client |
      userid: user.id,
      name: user.name,
      rank: user.rank,
      moderator: User.is_moderator?(user),
      bot: User.is_bot?(user),
      ip: stats["last_ip"],
      country: stats["country"],
      lobby_client: stats["lobby_client"]
    }
    |> add_client
  end

  # It appears this isn't used but I suspect it will be at a later stage
  # def get_client_state(pid) do
  #   GenServer.call(pid, :get_state)
  # end

  def disconnect(userid, reason \\ nil) do
    case get_client_by_id(userid) do
      nil -> nil
      client -> do_disconnect(client, reason)
    end
  end

  # If it's a test user, don't worry about actually disconnecting it
  defp do_disconnect(client, reason) do
    Logger.info("#{client.name}/##{client.userid} disconnected because #{reason}")
    Lobby.remove_user_from_any_battle(client.userid)
    Room.remove_user_from_any_room(client.userid)
    leave_rooms(client.userid)

    if client.bot do
      Telemetry.increment(:bots_disconnected)
    else
      Telemetry.increment(:users_disconnected)
    end

    # Typically we would only send the username but it is possible they just changed their username
    # and as such we need to tell the system what username is logging out
    PubSub.broadcast(
      Central.PubSub,
      "legacy_all_user_updates",
      {:user_logged_out, client.userid, client.name}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_action_updates:#{client.userid}",
      {:client_action, :client_disconnect, client.userid}
    )

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_client_inout",
      {:client_inout, :disconnect, client.userid, reason}
    )

    Central.cache_delete(:clients, client.userid)

    Central.cache_update(:lists, :clients, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != client.userid end)

      {:ok, new_value}
    end)
  end

  @spec chat_flood_check(T.userid()) :: :ok
  def chat_flood_check(userid) do
    now = System.system_time(:second)
    client = get_client_by_id(userid)
    new_times = [now | client.chat_times] |> Enum.take(@chat_flood_count_long)

    short_time = Enum.slice(new_times, @chat_flood_count_short - 1, 1) |> get_hd
    long_time = Enum.slice(new_times, @chat_flood_count_long - 1, 1) |> get_hd

    update(%{client | chat_times: new_times}, :silent)

    take_action = cond do
      client.bot -> false
      # client.moderator -> false
      now < (short_time + @chat_flood_time_short) -> true
      now < (long_time + @chat_flood_time_long) -> true
      true -> false
    end

    if take_action do
      user = User.get_user_by_id(userid)
      if (client.temp_mute_count + 1) == @temp_mute_count_limit do
        banned_until = HumanTime.relative!("300 seconds")
        new_mute = [true, banned_until]
        User.update_user(%{user | banned: new_mute}, persist: true)
        disconnect(userid, :chat_flood)

      else
        muted_until = TimexHelper.date_to_str(HumanTime.relative!("60 seconds"), :ymd_t_hms)
        new_mute = [true, muted_until]
        User.update_user(%{user | muted: new_mute}, persist: true)
        update(%{client | temp_mute_count: client.temp_mute_count + 1}, :silent)
        Coordinator.send_to_user(userid, "Chat flood protection enabled, please wait before sending more messages. Persist and you'll be temporarily banned.")
      end
    end
    :ok
  end

  @spec shadowban_client(T.userid()) :: :ok
  def shadowban_client(userid) do
    client = get_client_by_id(userid)
    update(%{client | shadowbanned: true}, :silent)
    :ok
  end

  @spec set_awaiting_warn_ack(T.userid()) :: :ok
  def set_awaiting_warn_ack(userid) do
    case get_client_by_id(userid) do
      nil ->
        :ok
      client ->
        update(%{client | awaiting_warn_ack: true}, :silent)
    end
    :ok
  end

  @spec clear_awaiting_warn_ack(T.userid()) :: :ok
  def clear_awaiting_warn_ack(userid) do
    client = get_client_by_id(userid)
    update(%{client | awaiting_warn_ack: false}, :silent)
    :ok
  end

  defp get_hd([]), do: 0
  defp get_hd(v), do: hd(v)

  @spec enable_client_message_print(T.userid()) :: :ok
  def enable_client_message_print(userid) do
    case get_client_by_id(userid) do
      nil -> :ok
      client ->
        send(client.pid, {:put, :print_client_messages, true})
        add_client(%{client | print_client_messages: true})
        :ok
    end
  end

  @spec disable_client_message_print(T.userid()) :: :ok
  def disable_client_message_print(userid) do
    case get_client_by_id(userid) do
      nil -> :ok
      client ->
        send(client.pid, {:put, :print_client_messages, false})
        add_client(%{client | print_client_messages: false})
        :ok
    end
  end

  @spec enable_server_message_print(T.userid()) :: :ok
  def enable_server_message_print(userid) do
    case get_client_by_id(userid) do
      nil -> :ok
      client ->
        send(client.pid, {:put, :print_server_messages, true})
        # add_client(%{client | print_server_messages: true})
        :ok
    end
  end

  @spec disable_server_message_print(T.userid()) :: :ok
  def disable_server_message_print(userid) do
    case get_client_by_id(userid) do
      nil -> :ok
      client ->
        send(client.pid, {:put, :print_server_messages, false})
        # add_client(%{client | print_server_messages: false})
        :ok
    end
  end
end
