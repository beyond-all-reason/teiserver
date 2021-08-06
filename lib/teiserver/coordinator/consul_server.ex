defmodule Teiserver.Coordinator.ConsulServer do
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
  alias Teiserver.{Coordinator, Client, User}
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

  @always_allow ~w(status help)

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

  def handle_call({:request_user_change_status, userid}, _from, state) do
    {:reply, allow_status_change?(userid, state), state}
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
    :timer.send_after(1000, :delayed_startup)
    {:noreply, state}
  end

  def handle_info(:delayed_startup, state) do
    uuid = UUID.uuid4()
    battle = Lobby.get_battle!(state.battle_id)
    new_tags = Map.put(battle.tags, "server/match/uuid", uuid)
    Lobby.set_script_tags(state.battle_id, new_tags)

    {:noreply, state}
  end

  def handle_info({:user_joined, userid}, state) do
    user = User.get_user_by_id(userid)

    if state.welcome_message do
      Lobby.sayprivateex(state.coordinator_id, userid, " #{user.name} - " <> state.welcome_message, state.battle_id)
    end

    # If the client is muted, we need to tell the host
    if User.is_muted?(userid) do
      Coordinator.send_to_host(state.coordinator_id, state.battle_id, "!mute #{user.name}")
    end

    {:noreply, state}
  end

  # # PubSub handlers
  # def handle_info({:battle_lobby_updated, _, _, _}, state), do: {:noreply, state}
  # def handle_info({:battle_lobby_closed, _}, state), do: {:noreply, state}
  # def handle_info({:add_bot_to_battle_lobby, _lobby_id, _bot}, state), do: {:noreply, state}
  # def handle_info({:update_bot_in_battle_lobby, _lobby_id, _botname, _new_bot}, state), do: {:noreply, state}
  # def handle_info({:remove_bot_from_battle_lobby, _lobby_id, _botname}, state), do: {:noreply, state}
  # def handle_info({:add_user_to_battle_lobby, _lobby_id, userid}, state), do: {:noreply, check_player_battlestatus(userid, :join_battle, state)}
  # def handle_info({:remove_user_from_battle_lobby, _lobby_id, _userid}, state), do: {:noreply, state}
  # def handle_info({:kick_user_from_battle_lobby, _lobby_id, _userid}, state), do: {:noreply, state}

  # def handle_info({:consul_server_updated, _, _}, state), do: {:noreply, state}

  # # Client
  # def handle_info({:updated_client_status, client, reason}, state), do: {:noreply, check_player_battlestatus(client, reason, state)}

  def handle_info(cmd = %{command: _}, state) do
    new_state = case allow_command?(cmd, state) do
      :allow ->
        handle_command(cmd, state)
      :with_vote ->
        handle_command(cmd, state)
      :existing_vote ->
        state
      :disallow ->
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
  def handle_command(%{command: "welcome-message", remaining: remaining} = cmd, state) do
    new_state = case String.trim(remaining) do
      "" ->
        %{state | welcome_message: nil}
      msg ->
        Lobby.say(cmd.senderid, "New welcome message set to: #{msg}", state.battle_id)
        %{state | welcome_message: msg}
    end
    broadcast_update(new_state)
  end

  def handle_command(%{command: "settag", remaining: remaining} = cmd, state) do
    case String.split(remaining, " ") do
      [key, value | _] ->
        battle = Lobby.get_battle!(state.battle_id)
        new_tags = Map.put(battle.tags, String.downcase(key), value)
        Lobby.set_script_tags(state.battle_id, new_tags)
        say_command(cmd, state)
      _ ->
        say_command(%{cmd | error: "no regex match"}, state)
    end
  end

  def handle_command(%{command: "help", senderid: senderid} = _cmd, state) do
    status_msg = [
      "Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "status", senderid: senderid} = _cmd, state) do
    status_msg = [
      "Status for battle ##{state.battle_id}",
      "Gatekeeper: #{state.gatekeeper}"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "reset"} = _cmd, state) do
    empty_state(state.battle_id)
    |> broadcast_update("reset")
  end

  def handle_command(%{command: "coordinator", remaining: "stop"} = cmd, state) do
    Lobby.stop_coordinator_mode(state.battle_id)
    say_command(cmd, state)
  end

  def handle_command(%{command: "manual-autohost"}, state) do
    Coordinator.send_to_host(state.coordinator_id, state.battle_id, "!autobalance off")
    state
  end

  # Normally we'd have this as a passthrough but we use it as part of the matchmaking
  # queue server to change the map.
  # TODO: Find a way to make this a passthrough
  def handle_command(%{command: "map", remaining: map_name} = cmd, state) do
    Coordinator.send_to_host(state.coordinator_id, state.battle_id, "!map #{map_name}")
    say_command(cmd, state)
  end

  def handle_command(%{command: "start", senderid: senderid} = cmd, state) do
    Coordinator.send_to_host(senderid, state.battle_id, "!start")
    say_command(cmd, state)
  end

  def handle_command(%{command: "forcestart", senderid: senderid} = cmd, state) do
    Coordinator.send_to_host(senderid, state.battle_id, "!forcestart")
    say_command(cmd, state)
  end



  def handle_command(%{command: "pull", remaining: target} = cmd, state) do
    # TODO: Make this work for friends only if not a mod
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_add_user_to_battle(target_id, state.battle_id)
        say_command(cmd, state)
    end
  end

  def handle_command(%{command: "force-spectator", remaining: target} = cmd, state) do
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
        say_command(cmd, state)
    end
  end

  # Would need to be sent by internal since battlestatus isn't part of the command queue
  def handle_command(%{command: "change-battlestatus", remaining: target_id, status: new_status}, state) do
    Lobby.force_change_client(state.coordinator_id, target_id, new_status)
    state
  end

  def handle_command(%{command: "lock-spectator", remaining: target} = _cmd, state) do
    case get_user(target, state) do
      nil ->
        state
      target_id ->
        new_blacklist = Map.put(state.blacklist, target_id, :spectator)
        new_whitelist = Map.put(state.whitelist, target_id, :spectator)
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})

        %{state | blacklist: new_blacklist, whitelist: new_whitelist}
        |> broadcast_update("lock-spectator")
    end
  end

  def handle_command(%{command: "kick", remaining: target} = cmd, state) do
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.kick_user_from_battle(int_parse(target_id), state.battle_id)
        say_command(cmd, state)
    end
  end

  def handle_command(%{command: "ban", remaining: target} = cmd, state) do
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_blacklist = Map.put(state.blacklist, target_id, :banned)
        new_whitelist = Map.delete(state.blacklist, target_id)
        Lobby.kick_user_from_battle(target_id, state.battle_id)

        say_command(cmd, state)

        %{state | blacklist: new_blacklist, whitelist: new_whitelist}
        |> broadcast_update("ban")
    end
  end

  def handle_command(%{command: "unban", remaining: target} = cmd, state) do
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_blacklist = Map.delete(state.blacklist, target_id)
        say_command(cmd, state)

        %{state | blacklist: new_blacklist}
        |> broadcast_update("unban")
    end
  end

  # TODO: Find out if this making spectators ready is a problem, it won't give them a team so should be fine
  def handle_command(%{command: "makeready", remaining: ""} = cmd, state) do
    battle = Lobby.get_battle!(state.battle_id)

    battle.players
    |> Enum.each(fn player_id ->
      Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
    end)

    say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: target} = cmd, state) do
    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{ready: true})
        say_command(cmd, state)
    end
  end

  def handle_command(%{command: "gatekeeper", remaining: mode} = cmd, state) do
    state = case mode do
      "blacklist" ->
        %{state | gatekeeper: :blacklist}
      "whitelist" ->
        %{state | gatekeeper: :whitelist}
      "friends" ->
        %{state | gatekeeper: :friends}
      "friendsjoin" ->
        %{state | gatekeeper: :friendsjoin}
      "clan" ->
        %{state | gatekeeper: :clan}
      _ ->
        state
    end
    say_command(cmd, state)
  end

  def handle_command(%{command: "blacklist", remaining: target_level} = cmd, state) do
    {target, level} = case String.split(target_level, " ") do
      [target, level | _] ->
        {target, get_level(level |> String.downcase())}
      [target] ->
        {target, :banned}
    end

    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        new_blacklist = if level == :player do
          Map.delete(state.blacklist, target_id)
        else
          Map.put(state.blacklist, target_id, level)
        end

        case level do
          :banned ->
            Lobby.kick_user_from_battle(target_id, state.battle_id)
          :spectator ->
            Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
          _ ->
            nil
        end

        say_command(cmd, state)

        %{state | blacklist: new_blacklist}
        |> broadcast_update("blacklist")
    end
  end

  def handle_command(%{command: "whitelist", remaining: "player-as-is"} = cmd, state) do
    battle = Lobby.get_battle!(state.battle_id)
    new_whitelist = battle.players
      |> Client.list_clients()
      |> Map.new(fn %{userid: userid, player: player} ->
        if player do
          {userid, :player}
        else
          {userid, :spectator}
        end
      end)
      |> Map.put(:default, :spectator)

    say_command(cmd, state)

    %{state | whitelist: new_whitelist}
    |> broadcast_update("whitelist")
  end

  def handle_command(%{command: "whitelist", remaining: "default " <> level} = cmd, state) do
    level = get_level(level |> String.downcase())
    battle = Lobby.get_battle!(state.battle_id)

    new_whitelist = Map.put(state.whitelist, :default, level)

    # Any players not already in the whitelist need to get added at their current level
    extra_entries = battle.players
      |> Enum.filter(fn userid -> not Map.has_key?(new_whitelist, userid) end)
      |> Client.list_clients
      |> Map.new(fn %{userid: userid, player: player} ->
        if player do
          {userid, :player}
        else
          {userid, :spectator}
        end
      end)

    new_whitelist = Map.merge(extra_entries, new_whitelist)

    say_command(cmd, state)

    %{state | whitelist: new_whitelist}
    |> broadcast_update("whitelist")
  end

  def handle_command(%{command: "whitelist", remaining: target_level} = cmd, state) do
    {target, level} = case String.split(target_level, " ") do
      [target, level | _] ->
        {target, get_level(level |> String.downcase())}
      [target] ->
        {target, :player}
    end

    case get_user(target, state) do
      nil ->
        say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        new_whitelist = if level == :banned do
          Map.delete(state.whitelist, target_id)
        else
          Map.put(state.whitelist, target_id, level)
        end

        case level do
          :banned ->
            Lobby.kick_user_from_battle(target_id, state.battle_id)
          :spectator ->
            Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
          _ ->
            nil
        end

        say_command(cmd, state)

        %{state | whitelist: new_whitelist}
        |> broadcast_update("whitelist")
    end
  end

  def handle_command(cmd, state) do
    Logger.error("No handler in consul_server for command type '#{cmd.command}'")
    Lobby.do_say(cmd.senderid, cmd.raw, state.battle_id)
    state
  end

  defp allow_status_change?(userid, state) when is_integer(userid) do
    client = Client.get_client_by_id(userid)
    allow_status_change?(client, state)
  end
  defp allow_status_change?(%{moderator: true}, _state), do: true
  defp allow_status_change?(%{userid: userid} = client, state) do
    list_status = get_list_status(userid, state)

    cond do
      list_status != :player and client.player == true -> false
      true -> true
    end
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

  defp get_list_status(userid, state) do
    case state.gatekeeper do
      :blacklist -> get_blacklist(userid, state.blacklist)
      :whitelist -> get_whitelist(userid, state.whitelist)
      :friends ->
        if is_on_friendlist?(userid, state, :players) do
          :player
        else
          :spectator
        end

      :friendsjoin ->
        if is_on_friendlist?(userid, state, :all) do
          :player
        else
          :banned
        end

      :clan ->
        # TODO: Implement
        :player
    end
  end

  defp is_on_friendlist?(userid, state, :players) do
    battle = Lobby.get_battle!(state.battle_id)
    players = battle.players
      |> Enum.map(&Client.get_client_by_id/1)
      |> Enum.filter(fn c -> c.player end)
      |> Enum.map(fn c -> c.userid end)

    # If battle has no players it'll succeed regardless
    case players do
      [] -> true
      _ ->
        players
          |> User.list_combined_friendslist
          |> Enum.member?(userid)
    end
  end

  defp is_on_friendlist?(userid, state, :all) do
    battle = Lobby.get_battle!(state.battle_id)

    # If battle has no members it'll succeed regardless
    case battle do
      %{players: []} -> true
      _ ->
        battle
          |> Map.get(:players)
          |> User.list_combined_friendslist
          |> Enum.member?(userid)
    end
  end

  defp allow_join?(userid, state) do
    client = Client.get_client_by_id(userid)

    cond do
      client.moderator ->
        true

      state.gatekeeper == :clan ->
        true

      state.gatekeeper == :friends ->
        true

      state.gatekeeper == :friendsjoin ->
        is_friend?(userid, state)

      state.gatekeeper == :blacklist and get_blacklist(userid, state.blacklist) == :banned ->
        false

      state.gatekeeper == :whitelist and get_whitelist(userid, state.whitelist) == :banned ->
        false

      true ->
        true
    end
  end

  defp broadcast_update(state, reason \\ nil) do
    Phoenix.PubSub.broadcast(
      Central.PubSub,
      "teiserver_battle_lobby_updates:#{state.battle_id}",
      {:consul_server_updated, state.battle_id, reason}
    )
    state
  end

  @spec allow_command?(Map.t(), Map.t()) :: :allow | :with_vote | :disallow | :existing_vote
  defp allow_command?(%{senderid: senderid} = cmd, state) do
    user = User.get_user_by_id(senderid)

    cond do
      Enum.member?(@always_allow, cmd.command) ->
        :allow

      senderid == state.coordinator_id ->
        :allow

      user == nil ->
        :disallow

      cmd.force == true and user.moderator == true ->
        :allow

      cmd.vote == true and state.current_vote != nil ->
        :existing_vote

      cmd.vote == true ->
        :with_vote

      true ->
        :with_vote
    end
  end

  @spec get_user(String.t() | integer(), Map.t()) :: integer() | nil
  defp get_user(id, _) when is_integer(id), do: id
  defp get_user("", _), do: nil
  defp get_user("#" <> id, _), do: int_parse(id)
  defp get_user(name, state) do
    case User.get_userid(name) do
      nil ->
        # Try partial search of players in lobby
        battle = Lobby.get_battle(state.battle_id)
        found = Client.list_clients(battle.players)
          |> Enum.filter(fn client ->
            String.contains?(client.name, name)
          end)

        case found do
          [first | _] ->
            first.userid
          _ ->
            nil
        end

      user ->
        user
    end
  end

  @spec is_friend?(T.userid(), Map.t()) :: boolean()
  defp is_friend?(_userid, _state) do
    true
  end

  @spec say_command(Map.t(), Map.t()) :: Map.t()
  defp say_command(%{silent: true}, state), do: state
  defp say_command(cmd, state) do
    vote = if Map.get(cmd, :vote), do: "cv ", else: ""
    force = if Map.get(cmd, :force), do: "force ", else: ""
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    msg = "! #{vote}#{force}#{cmd.command}#{remaining}#{error}"
      |> String.trim
    Lobby.say(cmd.senderid, msg, state.battle_id)
    state
  end

  # defp new_vote(cmd) do
  #   %{
  #     eligible: [],
  #     yays: [],
  #     nays: [],
  #     abstains: [],
  #     cmd: cmd
  #   }
  # end

  defp empty_state(battle_id) do
    %{
      current_vote: nil,
      coordinator_id: Coordinator.get_coordinator_userid(),
      battle_id: battle_id,
      gatekeeper: :blacklist,
      blacklist: %{},
      whitelist: %{
        :default => :player
      },
      temp_bans: %{},
      temp_specs: %{},
      boss_mode: :player,
      bosses: [],
      welcome_message: nil,
    }
  end

  defp get_level("banned"), do: :banned
  defp get_level("spectator"), do: :spectator
  defp get_level("player"), do: :player

  @spec init(Map.t()) :: {:ok, Map.t()}
  def init(opts) do
    battle_id = opts[:battle_id]

    # :ok = PubSub.subscribe(Central.PubSub, "teiserver_battle_lobby_updates:#{battle_id}")

    # Update the queue pids cache to point to this process
    ConCache.put(:teiserver_consul_pids, battle_id, self())

    {:ok, empty_state(battle_id)}
  end
end
