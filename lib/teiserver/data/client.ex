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
  alias Teiserver.User
  alias Teiserver.Room
  alias Teiserver.Battle.BattleLobby
  require Logger

  alias Teiserver.Data.Types, as: T

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
        team_number: 0,
        team_colour: 0,
        ally_team_number: 0,
        player: false,
        handicap: 0,
        sync: 0,
        side: 0,
        battle_id: nil
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
      battle_id: nil
    }
  end

  def login(user, pid) do
    client =
      create(%{
        userid: user.id,
        name: user.name,
        pid: pid,
        rank: user.rank,
        moderator: user.moderator,
        bot: user.bot,
        away: false,
        in_game: false,
        ip: user.ip,
        country: user.country,
        lobbyid: user.lobbyid
      })
      |> add_client

    PubSub.broadcast(
      Central.PubSub,
      "all_user_updates",
      {:user_logged_in, user.id}
    )

    client
  end

  @spec update(Map.t()) :: Map.t()
  @spec update(Map.t(), atom | nil) :: Map.t()
  def update(client, reason \\ nil) do
    client =
      client
      |> add_client

    PubSub.broadcast(Central.PubSub, "all_client_updates", {:updated_client, client, reason})

    if client.battle_id,
      do:
        PubSub.broadcast(
          Central.PubSub,
          "live_battle_updates:#{client.battle_id}",
          {:updated_client, client, reason}
        )

    client
  end

  @spec join_battle(T.client_id(), Integer.t(), Integer.t()) :: nil | Map.t()
  def join_battle(userid, battle_id, colour \\ 0) do
    case get_client_by_id(userid) do
      nil ->
        nil

      client ->
        new_client = reset_battlestatus(client)
        new_client = %{new_client | team_colour: colour, battle_id: battle_id}
        ConCache.put(:clients, new_client.userid, new_client)
        new_client
    end
  end

  @spec leave_battle(Integer.t() | nil) :: Map.t() | nil
  def leave_battle(nil), do: nil

  def leave_battle(userid) do
    case get_client_by_id(userid) do
      nil ->
        nil

      %{battle_id: nil} = client ->
        client

      client ->
        new_client = reset_battlestatus(client)
        ConCache.put(:clients, new_client.userid, new_client)
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
    ConCache.get(:clients, userid)
  end

  @spec get_client_by_id(Integer.t() | nil) :: nil | Map.t()
  def get_client_by_id(nil), do: nil

  def get_client_by_id(userid) do
    ConCache.get(:clients, userid)
  end

  @spec get_clients(List.t()) :: List.t()
  def get_clients([]), do: []

  def get_clients(id_list) do
    id_list
    |> Enum.map(fn userid -> ConCache.get(:clients, userid) end)
  end

  @spec add_client(Map.t()) :: Map.t()
  def add_client(client) do
    ConCache.put(:clients, client.userid, client)

    ConCache.update(:lists, :clients, fn value ->
      new_value =
        ([client.userid | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    client
  end

  @spec list_client_ids() :: List.t()
  def list_client_ids() do
    ConCache.get(:lists, :clients)
  end

  @spec list_clients() :: List.t()
  def list_clients() do
    ConCache.get(:lists, :clients)
    |> Enum.map(fn c -> get_client_by_id(c) end)
  end

  @spec refresh_client(T.userid()) :: Map.t()
  def refresh_client(userid) do
    user = User.get_user_by_id(userid)
    client = get_client_by_id(userid)
    %{client |
      userid: user.id,
      name: user.name,
      rank: user.rank,
      moderator: user.moderator,
      bot: user.bot,
      ip: user.ip,
      country: user.country,
      lobbyid: user.lobbyid
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
    is_test_user = String.contains?(client.name, "new_test_user_")

    BattleLobby.remove_user_from_any_battle(client.userid)
    Room.remove_user_from_any_room(client.userid)
    leave_rooms(client.userid)

    # If it's a test user then it can mean the db connection is closed
    # we don't actually care about logging out most of them and the
    # ones we do won't be called new_test_user_
    if not is_test_user do
      spawn(fn -> User.logout(client.userid) end)
      if client.name != nil and String.contains?(client.name, "new_test_user") == false do
        if reason do
          Logger.error("disconnect of #{client.name} (#{reason})")
        else
          Logger.error("disconnect of #{client.name}")
        end
      end
    end

    # Typically we would only send the username but it is possible they just changed their username
    # and as such we need to tell the system what username is logging out
    PubSub.broadcast(
      Central.PubSub,
      "all_user_updates",
      {:user_logged_out, client.userid, client.name}
    )

    ConCache.delete(:clients, client.userid)

    ConCache.update(:lists, :clients, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != client.userid end)

      {:ok, new_value}
    end)
  end
end
