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
  alias Teiserver.{Room, CacheUser, Account, Telemetry, Clans, Coordinator}
  alias Teiserver.Lobby
  alias Teiserver.Account.ClientLib
  # alias Teiserver.Helper.TimexHelper
  require Logger

  alias Teiserver.Data.Types, as: T

  @spec create(map()) :: map()
  def create(client) do
    Map.merge(
      %{
        connected: false,
        in_game: false,
        away: false,
        rank: 1,
        moderator: false,
        bot: false,

        # Battle stuff
        ready: false,
        unready_at: nil,
        # In spring this is team_number
        player_number: 0,
        team_colour: "0",
        # In spring this would be ally_team_number
        team_number: 0,
        player: false,
        handicap: 0,
        sync: %{
          engine: 0,
          game: 0,
          map: 0
        },
        side: 0,
        role: "spectator",
        lobby_id: nil,
        print_client_messages: false,
        print_server_messages: false,
        chat_times: [],
        temp_mute_count: 0,
        ip: nil,
        country: nil,
        lobby_client: nil,
        app_status: nil,
        shadowbanned: false,
        awaiting_warn_ack: false,
        warned: false,
        muted: false,
        restricted: false,
        lobby_host: false,
        queues: [],
        party_id: nil,
        clan_tag: nil,
        token_id: nil,
        protocol: nil
      },
      client
    )
  end

  @spec reset_battlestatus(map()) :: map()
  def reset_battlestatus(client) do
    %{
      client
      | player_number: 0,
        team_number: 0,
        player: false,
        handicap: 0,
        sync: %{
          engine: 0,
          game: 0,
          map: 0
        },
        role: "spectator",
        lobby_id: nil
    }
  end

  @spec login(T.user(), atom(), String.t() | nil) :: T.client()
  def login(user, protocol, ip \\ nil, token_id \\ nil) do
    stats = Account.get_user_stat_data(user.id)

    clan_tag =
      case Clans.get_clan(user.clan_id) do
        nil -> nil
        clan -> clan.tag
      end

    client =
      create(%{
        connected: true,
        userid: user.id,
        name: user.name,
        tcp_pid: self(),
        rank: user.rank,
        moderator: CacheUser.is_moderator?(user),
        bot: CacheUser.is_bot?(user),
        away: false,
        in_game: false,
        ip: ip || stats["last_ip"],
        country: stats["country"] || "??",
        lobby_client: stats["lobby_client"],
        shadowbanned: CacheUser.is_shadowbanned?(user),
        muted: CacheUser.has_mute?(user),
        awaiting_warn_ack: false,
        warned: false,
        token_id: token_id,
        clan_tag: clan_tag,
        protocol: protocol
      })

    ClientLib.start_client_server(client)

    PubSub.broadcast(
      Teiserver.PubSub,
      "client_inout",
      %{
        channel: "client_inout",
        event: :login,
        userid: user.id,
        client: client
      }
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{user.id}",
      %{
        channel: "teiserver_client_messages:#{user.id}",
        event: :connected
      }
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_watch:#{user.id}",
      %{
        channel: "teiserver_client_watch:#{user.id}",
        event: :connected
      }
    )

    # Message logging
    if user.print_client_messages do
      enable_client_message_print(user.id)
    end

    if user.print_server_messages do
      enable_server_message_print(user.id)
    end

    # Lets give everything a chance to propagate
    :timer.sleep(150)

    Logger.info("Client connected: #{client.name} using #{client.lobby_client}")

    if client.bot do
      Telemetry.increment(:bots_connected)
    else
      Telemetry.increment(:users_connected)
    end

    client
  end

  @spec get_client_by_name(nil) :: nil
  @spec get_client_by_name(String.t()) :: nil | T.client()
  defdelegate get_client_by_name(name), to: ClientLib

  @spec get_client_by_id(nil) :: nil
  @spec get_client_by_id(T.userid()) :: nil | T.client()
  defdelegate get_client_by_id(userid), to: ClientLib

  @spec get_clients([T.userid()]) :: List.t()
  defdelegate get_clients(id_list), to: ClientLib

  @spec list_client_ids() :: [T.userid()]
  defdelegate list_client_ids(), to: ClientLib

  @spec list_clients() :: [T.client()]
  defdelegate list_clients(), to: ClientLib

  @spec list_clients([T.userid()]) :: [T.client()]
  defdelegate list_clients(id_list), to: ClientLib

  @spec update(map(), :silent | :client_updated_status | :client_updated_battlestatus) ::
          T.client()
  def update(client, reason), do: ClientLib.replace_update_client(client, reason)

  @spec get_client_pid(T.userid()) :: pid() | nil
  defdelegate get_client_pid(userid), to: ClientLib

  @spec cast_client(T.userid(), any) :: any
  defdelegate cast_client(userid, msg), to: ClientLib

  @spec call_client(T.userid(), any) :: any | nil
  defdelegate call_client(userid, msg), to: ClientLib

  @spec join_battle(T.client_id(), Integer.t(), boolean()) :: nil | T.client()
  def join_battle(userid, lobby_id, lobby_host) do
    case get_client_by_id(userid) do
      nil ->
        nil

      client ->
        new_client = reset_battlestatus(client)
        new_client = %{new_client | lobby_id: lobby_id, lobby_host: lobby_host}
        ClientLib.replace_update_client(new_client, :silent)
        new_client
    end
  end

  @spec leave_battle(Integer.t() | nil) :: map() | nil
  def leave_battle(nil), do: nil

  def leave_battle(userid) do
    case get_client_by_id(userid) do
      nil ->
        nil

      %{lobby_id: nil} = client ->
        client

      client ->
        new_client = reset_battlestatus(client)
        ClientLib.replace_update_client(new_client, :silent)
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

  @spec disconnect(T.userid(), nil | String.t()) :: nil | :ok | {:error, any}
  def disconnect(userid, reason \\ nil) do
    case get_client_by_id(userid) do
      nil -> nil
      client -> do_disconnect(client, reason, false)
    end
  end

  @spec kick_disconnect(T.userid(), nil | String.t()) :: nil | :ok | {:error, any}
  def kick_disconnect(userid, reason \\ nil) do
    case get_client_by_id(userid) do
      nil -> nil
      client -> do_disconnect(client, reason, true)
    end
  end

  # If it's a test user, don't worry about actually disconnecting it
  defp do_disconnect(client, reason, kick) do
    if kick do
      Coordinator.send_to_host(client.lobby_id, "!gkick #{client.name}")
    end

    Telemetry.log_simple_server_event(client.userid, "disconnect:#{reason}")
    Lobby.remove_user_from_any_lobby(client.userid)
    Room.remove_user_from_any_room(client.userid)
    leave_rooms(client.userid)

    # If they are part of a party, lets leave it
    Account.leave_party(client.party_id, client.userid)

    # If a test goes wrong this can bork things and make it harder to
    # identify what actually went wrong
    if not Application.get_env(:teiserver, Teiserver)[:test_mode] do
      Account.update_cache_user(client.userid, %{last_logout: Timex.now()})
    end

    if client.bot do
      Telemetry.increment(:bots_disconnected)
    else
      Telemetry.increment(:users_disconnected)
    end

    # Kill lobby server process
    ClientLib.stop_client_server(client.userid)

    PubSub.broadcast(
      Teiserver.PubSub,
      "client_inout",
      %{
        channel: "client_inout",
        event: :disconnect,
        userid: client.userid,
        reason: reason
      }
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_messages:#{client.userid}",
      %{
        channel: "teiserver_client_messages:#{client.userid}",
        event: :disconnected
      }
    )

    PubSub.broadcast(
      Teiserver.PubSub,
      "teiserver_client_watch:#{client.userid}",
      %{
        channel: "teiserver_client_watch:#{client.userid}",
        event: :disconnected
      }
    )
  end

  @spec shadowban_client(T.userid()) :: :ok
  def shadowban_client(userid) do
    # client = get_client_by_id(userid)
    # update(%{client | shadowbanned: true}, :silent)
    disconnect(userid, "shadowban")
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

  @spec enable_client_message_print(T.userid()) :: :ok
  def enable_client_message_print(userid) do
    case get_client_by_id(userid) do
      nil ->
        :ok

      client ->
        send(client.tcp_pid, {:put, :print_client_messages, true})
        :ok
    end
  end

  @spec disable_client_message_print(T.userid()) :: :ok
  def disable_client_message_print(userid) do
    case get_client_by_id(userid) do
      nil ->
        :ok

      client ->
        send(client.tcp_pid, {:put, :print_client_messages, false})
        :ok
    end
  end

  @spec enable_server_message_print(T.userid()) :: :ok
  def enable_server_message_print(userid) do
    case get_client_by_id(userid) do
      nil ->
        :ok

      client ->
        send(client.tcp_pid, {:put, :print_server_messages, true})
        :ok
    end
  end

  @spec disable_server_message_print(T.userid()) :: :ok
  def disable_server_message_print(userid) do
    case get_client_by_id(userid) do
      nil ->
        :ok

      client ->
        send(client.tcp_pid, {:put, :print_server_messages, false})
        :ok
    end
  end
end
