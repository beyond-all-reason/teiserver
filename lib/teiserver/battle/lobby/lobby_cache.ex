defmodule Teiserver.Battle.LobbyCache do
  alias Phoenix.PubSub
  alias Teiserver.Coordinator
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Types, as: T

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  def update_lobby(battle, nil, _) do
    ConCache.put(:lobbies, battle.id, battle)
    battle
  end

  def update_lobby(battle, data, reason) do
    ConCache.put(:lobbies, battle.id, battle)

    if Enum.member?([:update_battle_info], reason) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_all_battle_updates",
        {:global_battle_updated, battle.id, reason}
      )
    else
      PubSub.broadcast(
        Central.PubSub,
        "legacy_battle_updates:#{battle.id}",
        {:battle_updated, battle.id, data, reason}
      )
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{battle.id}",
      {:lobby_update, :updated, battle.id, reason}
    )

    battle
  end

  @spec get_lobby!(T.lobby_id() | nil) :: T.lobby() | nil
  def get_lobby!(id) do
    ConCache.get(:lobbies, int_parse(id))
  end

  @spec get_lobby(integer()) :: T.lobby() | nil
  def get_lobby(id) do
    ConCache.get(:lobbies, int_parse(id))
  end

  @spec get_lobby_players!(T.lobby_id()) :: [integer()]
  def get_lobby_players!(id) do
    get_lobby!(id).players
  end

  @spec add_lobby(T.lobby()) :: T.lobby()
  def add_lobby(lobby) do
    ConCache.put(:lobbies, lobby.id, lobby)

    _consul_pid = Coordinator.start_consul(lobby.id)
    Lobby.start_battle_lobby_throttle(lobby.id)

    ConCache.update(:lists, :lobbies, fn value ->
      new_value =
        ([lobby.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    :ok = PubSub.broadcast(
      Central.PubSub,
      "legacy_all_battle_updates",
      {:global_battle_updated, lobby.id, :battle_opened}
    )

    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_global_battle_lobby_updates",
      {:battle_lobby_opened, lobby.id}
    )

    lobby
  end

  @spec close_lobby(integer() | nil, atom) :: :ok
  def close_lobby(lobby_id, reason \\ :closed) do
    battle = get_lobby(lobby_id)
    Coordinator.close_battle(lobby_id)
    ConCache.delete(:lobbies, lobby_id)
    ConCache.update(:lists, :lobbies, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != lobby_id end)

      {:ok, new_value}
    end)

    [battle.founder_id | battle.players]
    |> Enum.each(fn userid ->
      PubSub.broadcast(
        Central.PubSub,
        "legacy_battle_updates:#{lobby_id}",
        {:remove_user_from_battle, userid, lobby_id}
      )
    end)

    PubSub.broadcast(
      Central.PubSub,
      "legacy_all_battle_updates",
      {:global_battle_updated, lobby_id, :battle_closed}
    )

    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_global_battle_lobby_updates",
      {:battle_lobby_closed, battle.id}
    )

    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{battle.id}",
      {:lobby_update, :closed, battle.id, reason}
    )

    Lobby.stop_battle_lobby_throttle(lobby_id)
  end
end
