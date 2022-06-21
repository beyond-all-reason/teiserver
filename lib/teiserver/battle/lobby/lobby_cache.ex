defmodule Teiserver.Battle.LobbyCache do
  alias Phoenix.PubSub
  alias Teiserver.Coordinator
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Types, as: T
  require Logger

  @spec get_lobby(T.lobby_id()) :: T.lobby() | nil
  def get_lobby(id) do
    # Central.cache_get(:lobbies, int_parse(id))
    call_lobby(int_parse(id), :get_lobby_state)
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

  @spec list_lobby_ids :: [T.lobby_id()]
  def list_lobby_ids() do
    # case Central.cache_get(:lists, :lobbies) do
    #   nil -> []
    #   ids -> ids
    # end
    Horde.Registry.select(Teiserver.LobbyRegistry, [{{:"$1", :_, :_}, [], [:"$1"]}])
  end

  @spec list_lobbies() :: [T.lobby()]
  def list_lobbies() do
    list_lobby_ids()
      |> Enum.map(fn lobby_id -> get_lobby(lobby_id) end)
      |> Enum.filter(fn lobby -> lobby != nil end)
  end

  @spec update_lobby_value(T.lobby_id(), atom, any) :: :ok | nil
  def update_lobby_value(lobby_id, key, value) do
    result = cast_lobby(lobby_id, {:update_value, key, value})

    if result != nil do
      # case key do
      #   _ ->
      #    :ok
      # end

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_lobby_updates:#{lobby_id}",
        {:lobby_update, :update_value, lobby_id, {key, value}}
      )
    end

    result
  end

  @spec update_lobby(T.lobby(), nil | atom, any) :: T.lobby()
  def update_lobby(%{id: lobby_id} = lobby, nil, :silent) do
    Central.cache_put(:lobbies, lobby_id, lobby)
    cast_lobby(lobby_id, {:update_lobby, lobby})

    lobby
  end

  def update_lobby(%{id: lobby_id} = lobby, nil, reason) do
    Central.cache_put(:lobbies, lobby.id, lobby)
    cast_lobby(lobby_id, {:update_lobby, lobby})

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

  def update_lobby(%{id: lobby_id} = lobby, data, reason) do
    Central.cache_put(:lobbies, lobby.id, lobby)
    cast_lobby(lobby_id, {:update_lobby, lobby})

    if Enum.member?([:update_battle_info], reason) do
      PubSub.broadcast(
        Central.PubSub,
        "legacy_all_battle_updates",
        {:global_battle_updated, lobby.id, reason}
      )

      PubSub.broadcast(
        Central.PubSub,
        "teiserver_global_battle_lobby_updates",
        {:global_battle_lobby, :update_battle_info, lobby.id}
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


  @spec add_user_to_lobby(T.userid(), T.lobby_id(), String.t()) :: nil | :ok
  def add_user_to_lobby(userid, lobby_id, script_password) do
    cast_lobby(lobby_id, {:add_user, userid, script_password})
  end

  @spec remove_user_from_lobby(T.userid(), T.lobby_id()) :: nil | :ok
  def remove_user_from_lobby(userid, lobby_id) do
    cast_lobby(lobby_id, {:remove_user, userid})
  end

  @spec get_lobby_member_list(T.lobby_id()) :: [T.userid()]
  def get_lobby_member_list(lobby_id) do
    call_lobby(lobby_id, :get_member_list)
  end

  @spec get_lobby_member_count(T.lobby_id()) :: integer() | :lobby
  def get_lobby_member_count(lobby_id) do
    call_lobby(lobby_id, :get_member_count)
  end

  @spec get_lobby_player_count(T.lobby_id()) :: integer() | :lobby
  def get_lobby_player_count(lobby_id) do
    call_lobby(lobby_id, :get_player_count)
  end

  @spec get_lobby_players(T.lobby_id()) :: [integer()]
  def get_lobby_players(lobby_id) do
    call_lobby(lobby_id, :get_player_list)
  end

  @spec get_lobby_players!(T.lobby_id()) :: [integer()]
  def get_lobby_players!(id) do
    get_lobby(id).players
  end

  @spec add_lobby(T.lobby()) :: T.lobby()
  def add_lobby(%{founder_id: _} = lobby) do
    Central.cache_put(:lobbies, lobby.id, lobby)

    Lobby.start_battle_lobby_throttle(lobby.id)
    start_lobby_server(lobby)

    _consul_pid = Coordinator.start_consul(lobby.id)

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

  @spec start_lobby_server(T.lobby()) :: pid()
  def start_lobby_server(lobby) do
    {:ok, server_pid} =
      DynamicSupervisor.start_child(Teiserver.LobbySupervisor, {
        Teiserver.Battle.LobbyServer,
        name: "lobby_#{lobby.id}",
        data: %{
          lobby: lobby
        }
      })

    server_pid
  end

  @spec lobby_exists?(T.lobby_id()) :: boolean()
  def lobby_exists?(lobby_id) do
    case get_lobby_pid(lobby_id) do
      nil -> false
      _ -> true
    end
  end

  @spec get_lobby_pid(T.lobby_id()) :: pid() | nil
  def get_lobby_pid(lobby_id) do
    case Horde.Registry.lookup(Teiserver.LobbyRegistry, lobby_id) do
      [{pid, _}] -> pid
      _ -> nil
    end
  end

  @doc """
  GenServer.cast the message to the LobbyServer process for lobby_id
  """
  @spec cast_lobby(T.lobby_id(), any) :: :ok | nil
  def cast_lobby(lobby_id, message) do
    case get_lobby_pid(lobby_id) do
      nil -> nil
      pid ->
        GenServer.cast(pid, message)
        :ok
    end
  end

  @doc """
  GenServer.call the message to the LobbyServer process for lobby_id and return the result
  """
  @spec call_lobby(T.lobby_id(), any) :: any | nil
  def call_lobby(lobby_id, message) do
    case get_lobby_pid(lobby_id) do
      nil -> nil
      pid -> GenServer.call(pid, message)
    end
  end

  @spec stop_lobby_server(T.lobby_id()) :: :ok | nil
  def stop_lobby_server(lobby_id) do
    case get_lobby_pid(lobby_id) do
      nil -> nil
      p ->
        DynamicSupervisor.terminate_child(Teiserver.LobbySupervisor, p)
        :ok
    end
  end


  @spec close_lobby(integer() | nil, atom) :: :ok
  def close_lobby(lobby_id, reason \\ :closed) do
    battle = get_lobby(lobby_id)
    Coordinator.close_lobby(lobby_id)
    Central.cache_delete(:lobbies, lobby_id)
    Central.cache_update(:lists, :lobbies, fn value ->
      new_value =
        value
        |> Enum.filter(fn v -> v != lobby_id end)

      {:ok, new_value}
    end)

    # Kill lobby server process
    stop_lobby_server(lobby_id)

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
end
