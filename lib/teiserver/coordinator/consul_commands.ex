defmodule Teiserver.Coordinator.ConsulCommands do
  require Logger
  alias Teiserver.Coordinator.ConsulServer
  alias Teiserver.{Coordinator, Client, User}
  alias Teiserver.Account.UserCache
  alias Teiserver.Battle.Lobby
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  # alias Phoenix.PubSub
  alias Teiserver.Data.Types, as: T

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
  @spec handle_command(Map.t(), Map.t()) :: Map.t()
  def handle_command(%{command: "welcome-message", remaining: remaining} = cmd, state) do
    new_state = case String.trim(remaining) do
      "" ->
        %{state | welcome_message: nil}
      msg ->
        Lobby.say(cmd.senderid, "New welcome message set to: #{msg}", state.lobby_id)
        %{state | welcome_message: msg}
    end
    ConsulServer.broadcast_update(new_state)
  end

  def handle_command(%{command: "settag", remaining: remaining} = cmd, state) do
    case String.split(remaining, " ") do
      [key, value | _] ->
        battle = Lobby.get_lobby!(state.lobby_id)
        new_tags = Map.put(battle.tags, String.downcase(key), value)
        Lobby.set_script_tags(state.lobby_id, new_tags)
        ConsulServer.say_command(cmd, state)
      _ ->
        ConsulServer.say_command(%{cmd | error: "no regex match"}, state)
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
      "Status for battle ##{state.lobby_id}",
      "Gatekeeper: #{state.gatekeeper}"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "reset"} = _cmd, state) do
    ConsulServer.empty_state(state.lobby_id)
    |> ConsulServer.broadcast_update("reset")
  end

  def handle_command(%{command: "coordinator", remaining: "stop"} = cmd, state) do
    Lobby.stop_coordinator_mode(state.lobby_id)
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "manual-autohost"}, state) do
    Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!autobalance off")
    state
  end

  # TODO: Swap this back over to `map` once we have voting working etc
  def handle_command(%{command: "changemap", remaining: map_name} = cmd, state) do
    Coordinator.send_to_host(state.coordinator_id, state.lobby_id, "!map #{map_name}")
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "start", senderid: senderid} = cmd, state) do
    Coordinator.send_to_host(senderid, state.lobby_id, "!start")
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "forcestart", senderid: senderid} = cmd, state) do
    Coordinator.send_to_host(senderid, state.lobby_id, "!forcestart")
    ConsulServer.say_command(cmd, state)
  end



  def handle_command(%{command: "pull", remaining: target} = cmd, state) do
    # TODO: Make this work for friends only if not a mod
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_add_user_to_battle(target_id, state.lobby_id)
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "force-spectator", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
        ConsulServer.say_command(cmd, state)
    end
  end

  # Would need to be sent by internal since battlestatus isn't part of the command queue
  def handle_command(%{command: "change-battlestatus", remaining: target_id, status: new_status}, state) do
    Lobby.force_change_client(state.coordinator_id, target_id, new_status)
    state
  end

  def handle_command(%{command: "lock-spectator", remaining: target} = _cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        state
      target_id ->
        new_blacklist = Map.put(state.blacklist, target_id, :spectator)
        new_whitelist = Map.put(state.whitelist, target_id, :spectator)
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})

        %{state | blacklist: new_blacklist, whitelist: new_whitelist}
        |> ConsulServer.broadcast_update("lock-spectator")
    end
  end

  def handle_command(%{command: "kick", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.kick_user_from_battle(int_parse(target_id), state.lobby_id)
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "ban", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_blacklist = Map.put(state.blacklist, target_id, :banned)
        new_whitelist = Map.delete(state.blacklist, target_id)
        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)

        %{state | blacklist: new_blacklist, whitelist: new_whitelist}
        |> ConsulServer.broadcast_update("ban")
    end
  end

  def handle_command(%{command: "unban", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_blacklist = Map.delete(state.blacklist, target_id)
        ConsulServer.say_command(cmd, state)

        %{state | blacklist: new_blacklist}
        |> ConsulServer.broadcast_update("unban")
    end
  end

  # TODO: Find out if this making spectators ready is a problem, it won't give them a team so should be fine
  def handle_command(%{command: "makeready", remaining: ""} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{ready: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "specunready"} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Client.get_client_by_id(player_id)
      if client.ready == false do
        Lobby.force_change_client(state.coordinator_id, player_id, %{player: false})
      end
    end)

    ConsulServer.say_command(cmd, state)
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
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "blacklist", remaining: target_level} = cmd, state) do
    {target, level} = case String.split(target_level, " ") do
      [target, level | _] ->
        {target, ConsulServer.get_level(level |> String.downcase())}
      [target] ->
        {target, :banned}
    end

    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        new_blacklist = if level == :player do
          Map.delete(state.blacklist, target_id)
        else
          Map.put(state.blacklist, target_id, level)
        end

        case level do
          :banned ->
            Lobby.kick_user_from_battle(target_id, state.lobby_id)
          :spectator ->
            Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
          _ ->
            nil
        end

        ConsulServer.say_command(cmd, state)

        %{state | blacklist: new_blacklist}
        |> ConsulServer.broadcast_update("blacklist")
    end
  end

  def handle_command(%{command: "whitelist", remaining: "player-as-is"} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)
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

    ConsulServer.say_command(cmd, state)

    %{state | whitelist: new_whitelist}
    |> ConsulServer.broadcast_update("whitelist")
  end

  def handle_command(%{command: "whitelist", remaining: "default " <> level} = cmd, state) do
    level = ConsulServer.get_level(level |> String.downcase())
    battle = Lobby.get_lobby!(state.lobby_id)

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

    ConsulServer.say_command(cmd, state)

    %{state | whitelist: new_whitelist}
    |> ConsulServer.broadcast_update("whitelist")
  end

  def handle_command(%{command: "whitelist", remaining: target_level} = cmd, state) do
    {target, level} = case String.split(target_level, " ") do
      [target, level | _] ->
        {target, ConsulServer.get_level(level |> String.downcase())}
      [target] ->
        {target, :player}
    end

    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        new_whitelist = if level == :banned do
          Map.delete(state.whitelist, target_id)
        else
          Map.put(state.whitelist, target_id, level)
        end

        case level do
          :banned ->
            Lobby.kick_user_from_battle(target_id, state.lobby_id)
          :spectator ->
            Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
          _ ->
            nil
        end

        ConsulServer.say_command(cmd, state)

        %{state | whitelist: new_whitelist}
        |> ConsulServer.broadcast_update("whitelist")
    end
  end

  def handle_command(cmd, state) do
    if Map.has_key?(cmd, :raw) do
      Lobby.do_say(cmd.senderid, cmd.raw, state.lobby_id)
    else
      Logger.error("No handler in consul_server for command #{Kernel.inspect cmd}")
    end
    state
  end
end
