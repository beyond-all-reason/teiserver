defmodule Teiserver.Director.ConsulServer do
  @moduledoc """
  One consul server is created for each battle. It acts as a battle supervisor in addition to any
  host.

  ### State values
    Blacklist is a map of userids linking to the level they're allowed to go:
      :banned --> Cannot join the battle
      :spectator --> Can only spectate
      :player --> Can play the game (missing keys default to this)

    Whitelist works on the level they are allowed to go
      :spectator --> Can be a spectator
      :player --> Can be a player

      Whitelist also has a :default key, if you are not in the whitelist then you
      are limited by the default key (e.g. only certain people can play, anybody can spectate)
      if :default is set to :banned then by default anybody not on the whitelist cannot join the game
  """
  use GenServer
  require Logger
  alias Teiserver.{Director, Client, User}
  alias Teiserver.Battle.BattleLobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]

  @spec start_link(List.t()) :: :ignore | {:error, any} | {:ok, pid}
  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts[:data], [])
  end

  def handle_call(:get_all, _from, state) do
    {:reply, state, state}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, Map.get(state, key), state}
  end

  def handle_call({:request_user_join_battle, userid}, _from, state) do
    {:reply, allow_join?(userid, state), state}
  end

  # Infos
  def handle_info({:put, key, value}, state) do
    new_state = Map.put(state, key, value)
    {:noreply, new_state}
  end

  def handle_info({:merge, new_map}, state) do
    new_state = Map.merge(state, new_map)
    {:noreply, new_state}
  end

  # Doesn't do anything at this stage
  def handle_info(:startup, state) do
    {:noreply, state}
  end

  def handle_info({:user_joined, userid}, state) do
    if state.welcome_message do
      username = User.get_username(userid)
      BattleLobby.sayprivateex(state.coordinator_id, userid, " #{username} - " <> state.welcome_message, state.battle_id)
    end

    {:noreply, state}
  end

  def handle_info(cmd = %{command: _}, state) do
    new_state = if allow_cmd?(cmd, state) do
      handle_command(cmd, state)
    else
      state
    end
    {:noreply, new_state}
  end

  @doc """
    Command has structure:
    %{
      raw: string,
      remaining: string,
      vote: boolean,
      command: nil | string,
      senderid: userid
    }
  """
  def handle_command(%{command: "welcome-message", remaining: remaining} = _cmd, state) do
    new_state = case String.trim(remaining) do
      "" ->
        %{state | welcome_message: nil}
      msg ->
        %{state | welcome_message: msg}
    end
    broadcast_update(new_state)
  end

  def handle_command(%{command: "start", senderid: senderid} = _cmd, state) do
    Director.send_to_host(senderid, state.battle, "!start")
    state
  end

  def handle_command(%{command: "reset"} = _cmd, state) do
    empty_state(state.battle_id)
    |> broadcast_update("lock-spectator")
  end

  def handle_command(%{command: "director", remaining: "stop"} = _cmd, state) do
    BattleLobby.stop_director_mode(state.battle_id)
    state
  end

  def handle_command(%{command: "force-spectator", remaining: target_id}, state)
      when is_integer(target_id) do
    BattleLobby.force_change_client(state.coordinator_id, target_id, :player, false)
    state
  end

  def handle_command(%{command: "lock-spectator", remaining: target_id} = _cmd, state) do
    target_id = int_parse(target_id)
    new_blacklist = Map.put(state.blacklist, target_id, :spectator)
    BattleLobby.force_change_client(state.coordinator_id, target_id, :player, false)

    %{state | blacklist: new_blacklist}
    |> broadcast_update("lock-spectator")
  end

  def handle_command(%{command: "kick", remaining: target_id} = _cmd, state)
      when is_integer(target_id) do
    BattleLobby.kick_user_from_battle(int_parse(target_id), state.battle_id)
    state
  end

  def handle_command(%{command: "ban", remaining: target_id} = _cmd, state)
      when is_integer(target_id) do
    target_id = int_parse(target_id)
    new_blacklist = Map.put(state.blacklist, target_id, :banned)
    BattleLobby.kick_user_from_battle(target_id, state.battle_id)

    %{state | blacklist: new_blacklist}
    |> broadcast_update("ban")
  end

  # Some commands expect remaining to be an integer, this is a catch for that
  def handle_command(%{remaining: target_name} = cmd, state) do
    case User.get_userid(target_name) do
      nil -> state
      userid -> handle_command(%{cmd | remaining: userid}, state)
    end
  end

  def handle_command(%{command: command} = _cmd, state) do
    Logger.error("No handler in consul_server for command type '#{command}'")
    state
  end

  defp get_blacklist(userid, blacklist_map) do
    Map.get(blacklist_map, userid, :player)
  end

  defp get_whitelist(userid, whitelist_map) do
    case Map.has_key?(whitelist_map, userid) do
      true -> Map.get(whitelist_map, userid)
      false -> Map.get(whitelist_map, :default)
    end
  end

  defp allow_join?(userid, state) do
    client = Client.get_client_by_id(userid)

    cond do
      client.moderator ->
        true

      state.guard_mode == :blacklist and get_blacklist(userid, state.blacklist) == :banned ->
        false

      state.guard_mode == :blacklist and get_whitelist(userid, state.whitelist) == :banned ->
        false

      true ->
        true
    end
  end

  defp broadcast_update(state, reason \\ nil) do
    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "live_battle_updates:#{state.battle_id}",
      {:consul_server_updated, state.battle_id, reason}
    )
    state
  end

  defp allow_cmd?(%{senderid: senderid} = _cmd, _state) do
    user = User.get_user_by_id(senderid)

    cond do
      user == nil ->
        false

      user.moderator ->
        true

      true ->
        true
    end
  end

  defp empty_state(battle_id) do
    %{
      coordinator_id: Director.get_coordinator_userid(),
      battle_id: battle_id,
      guard_mode: :blacklist,
      blacklist: %{},
      whitelist: %{
        default: :player
      },
      welcome_message: nil
    }
  end

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    {:ok, empty_state(opts[:battle_id])}
  end
end
