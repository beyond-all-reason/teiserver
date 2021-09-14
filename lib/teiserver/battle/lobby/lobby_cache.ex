defmodule Teiserver.Battle.LobbyCache do
  alias Phoenix.PubSub
  alias Teiserver.Coordinator
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Battle.Lobby

  @spec update_lobby(Map.t(), nil | atom, any) :: Map.t()
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

  def get_lobby!(id) do
    ConCache.get(:lobbies, int_parse(id))
  end

  @spec get_lobby(integer()) :: map() | nil
  def get_lobby(id) do
    ConCache.get(:lobbies, int_parse(id))
  end

  @spec get_lobby_players!(T.lobby_id()) :: [integer()]
  def get_lobby_players!(id) do
    get_lobby!(id).players
  end

  @spec add_lobby(Map.t()) :: Map.t()
  def add_lobby(battle) do
    _consul_pid = Coordinator.start_consul(battle.id)
    Lobby.start_battle_lobby_throttle(battle.id)

    ConCache.put(:lobbies, battle.id, battle)

    ConCache.update(:lists, :lobbies, fn value ->
      new_value =
        ([battle.id | value])
        |> Enum.uniq()

      {:ok, new_value}
    end)

    :ok = PubSub.broadcast(
      Central.PubSub,
      "legacy_all_battle_updates",
      {:global_battle_updated, battle.id, :battle_opened}
    )

    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_global_battle_lobby_updates",
      {:battle_lobby_opened, battle.id}
    )

    battle
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
