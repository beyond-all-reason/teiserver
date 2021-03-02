defmodule Teiserver.Client do
  @moduledoc false
  alias Phoenix.PubSub
  alias Teiserver.Battle
  alias Teiserver.User
  alias Teiserver.Room

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
        spectator: true,
        handicap: 0,
        sync: 0,
        side: 0,

        battle_id: nil
      },
      client
    )
  end

  def login(user, pid, protocol) do
    client =
      create(%{
        userid: user.id,
        name: user.name,
        pid: pid,
        protocol: protocol,
        rank: user.rank,
        moderator: user.moderator,
        bot: user.bot,
        away: false,
        in_game: false,
        ip: user.ip,
        country: user.country,
        lobbyid: user.lobbyid,
      })
      |> add_client

    PubSub.broadcast(
      Central.PubSub,
      "all_client_updates",
      {:logged_in_client, user.id, user.name}
    )

    client
  end

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

  def join_battle(userid, battle_id) do
    case get_client_by_id(userid) do
      nil ->
        nil

      client ->
        case Battle.get_battle(client.battle_id) do
          nil ->
            nil

          _battle ->
            new_client =
              Map.merge(client, %{
                team_colour: 0,
                battle_id: battle_id
              })

            ConCache.put(:clients, new_client.userid, new_client)
        end
    end
  end

  def leave_battle(userid) do
    case get_client_by_id(userid) do
      nil ->
        nil

      client ->
        case Battle.get_battle(client.battle_id) do
          nil ->
            nil

          _battle ->
            Battle.remove_user_from_battle(userid, client.battle_id)

            new_client =
              Map.merge(client, %{
                team_colour: 0,
                battle_id: nil
              })

            ConCache.put(:clients, new_client.userid, new_client)
        end
    end
  end

  def leave_rooms(userid) do
    Room.list_rooms()
    |> Enum.each(fn room ->
      if userid in room.members do
        Room.remove_user_from_room(userid, room.name)
      end
    end)
  end

  def get_client_by_name(name) do
    userid = User.get_userid(name)
    ConCache.get(:clients, userid)
  end

  def get_client_by_id(userid) do
    ConCache.get(:clients, userid)
  end

  def get_clients(id_list) do
    id_list
    |> Enum.map(fn userid -> ConCache.get(:clients, userid) end)
  end

  def add_client(client) do
    ConCache.put(:clients, client.userid, client)

    ConCache.update(:lists, :clients, fn value ->
      new_value =
        (value ++ [client.userid])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    client
  end

  def list_client_ids() do
    ConCache.get(:lists, :clients)
  end

  def list_clients() do
    ConCache.get(:lists, :clients)
    |> Enum.map(fn c -> get_client_by_id(c) end)
  end

  # It appears this isn't used but I suspect it will be at a later stage
  # def get_client_state(pid) do
  #   GenServer.call(pid, :get_state)
  # end

  def disconnect(nil), do: nil

  def disconnect(userid) do
    leave_battle(userid)
    leave_rooms(userid)
    User.logout(userid)

    ConCache.delete(:clients, userid)

    ConCache.update(:lists, :clients, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != userid end)

      {:ok, new_value}
    end)

    username = User.get_username(userid)
    PubSub.broadcast(Central.PubSub, "all_client_updates", {:logged_out_client, userid, username})
  end
end
