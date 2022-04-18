defmodule Teiserver.Battle.LobbyCache do
  alias Phoenix.PubSub
  alias Teiserver.Coordinator
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Types, as: T
  require Logger

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  def update_lobby(lobby, nil, :silent) do
    Central.cache_put(:lobbies, lobby.id, lobby)
    lobby
  end

  def update_lobby(lobby, nil, reason) do
    Central.cache_put(:lobbies, lobby.id, lobby)

    if Enum.member?([:rename], reason) do
      PubSub.broadcast(
        Central.PubSub,
        "teiserver_global_battle_lobby_updates",
        {:global_battle_lobby, :rename, lobby.id}
      )
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{lobby.id}",
      {:lobby_update, :updated, lobby.id, reason}
    )

    lobby
  end

  def update_lobby(lobby, data, reason) do
    Central.cache_put(:lobbies, lobby.id, lobby)

    if Enum.member?([:update_battle_info], reason) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_all_battle_updates",
        {:global_battle_updated, lobby.id, reason}
      )
    else
      PubSub.broadcast(
        Central.PubSub,
        "legacy_battle_updates:#{lobby.id}",
        {:battle_updated, lobby.id, data, reason}
      )
    end

    PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{lobby.id}",
      {:lobby_update, :updated, lobby.id, reason}
    )

    lobby
  end

  @spec get_lobby(integer()) :: T.lobby() | nil
  def get_lobby(id) do
    Central.cache_get(:lobbies, int_parse(id))
  end

  @spec get_lobby_by_uuid(String.t()) :: T.lobby() | nil
  def get_lobby_by_uuid(uuid) do
    lobby_list = list_lobbies()
      |> Enum.filter(fn lobby -> lobby.tags["server/match/uuid"] == uuid end)

    case lobby_list do
      [] -> nil
      [lobby | _] -> lobby
    end
  end

  @spec get_lobby_players!(T.lobby_id()) :: [integer()]
  def get_lobby_players!(id) do
    get_lobby(id).players
  end

  @spec add_lobby(T.lobby()) :: T.lobby()
  def add_lobby(lobby) do
    Central.cache_put(:lobbies, lobby.id, lobby)

    _consul_pid = Coordinator.start_consul(lobby.id)
    Lobby.start_battle_lobby_throttle(lobby.id)

    Central.cache_update(:lists, :lobbies, fn value ->
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
      {:global_battle_lobby, :opened, lobby.id}
    )

    lobby
  end

  @spec close_lobby(integer() | nil, atom) :: :ok
  def close_lobby(lobby_id, reason \\ :closed) do
    battle = get_lobby(lobby_id)
    Coordinator.close_battle(lobby_id)
    Central.cache_delete(:lobbies, lobby_id)
    Central.cache_update(:lists, :lobbies, fn value ->
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
      {:global_battle_lobby, :closed, battle.id}
    )

    :ok = PubSub.broadcast(
      Central.PubSub,
      "teiserver_lobby_updates:#{battle.id}",
      {:lobby_update, :closed, battle.id, reason}
    )

    Lobby.stop_battle_lobby_throttle(lobby_id)
  end

  @spec list_lobby_ids :: [non_neg_integer()]
  def list_lobby_ids() do
    case Central.cache_get(:lists, :lobbies) do
      nil -> []
      ids -> ids
    end
  end

  @spec list_lobbies() :: list()
  def list_lobbies() do
    list_lobby_ids()
      |> Enum.map(fn lobby_id -> Central.cache_get(:lobbies, lobby_id) end)
      |> Enum.filter(fn lobby -> lobby != nil end)
  end
end
