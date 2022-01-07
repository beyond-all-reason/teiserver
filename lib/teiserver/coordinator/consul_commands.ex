defmodule Teiserver.Coordinator.ConsulCommands do
  require Logger
  alias Teiserver.Coordinator.ConsulServer
  alias Teiserver.{Coordinator, User, Client}
  alias Teiserver.Battle.{Lobby, LobbyChat}
  # alias Phoenix.PubSub
  # alias Teiserver.Data.Types, as: T

  @doc """
    Command has structure:
    %{
      raw: string,
      remaining: string,
      command: nil | string,
      senderid: userid
    }
  """
  @split_delay 30_000
  @spec handle_command(Map.t(), Map.t()) :: Map.t()
  @default_ban_reason "Banned"

  #################### For everybody
  def handle_command(%{command: "s"} = cmd, state), do: handle_command(Map.put(cmd, :command, "status"), state)
  def handle_command(%{command: "status", senderid: senderid} = _cmd, state) do
    locks = state.locks
    |> Enum.map(fn l -> to_string(l) end)
    |> Enum.join(", ")

    pos_str = case get_queue_position(state.join_queue, senderid) do
      -1 ->
        nil
      pos ->
        "You are position #{pos} in the queue"
    end

    queue_string = state.join_queue
    |> Enum.map(&User.get_username/1)
    |> Enum.join(", ")

    # Put other settings in here
    other_settings = [
      (if state.welcome_message, do: "Welcome message: #{state.welcome_message}"),
      "Team size set to #{state.host_teamsize}",
      "Team count set to #{state.host_teamcount}",
      "Level required to play is #{state.level_to_play}",
      "Level required to spectate is #{state.level_to_spectate}",
    ]
    |> Enum.filter(fn v -> v != nil end)

    status_msg = [
      "Status for battle ##{state.lobby_id}",
      "Locks: #{locks}",
      "Gatekeeper: #{state.gatekeeper}",
      pos_str,
      "Join queue: #{queue_string}",
      other_settings,
    ]
    |> List.flatten
    |> Enum.filter(fn s -> s != nil end)

    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "help", senderid: senderid} = cmd, state) do
    user = User.get_user_by_id(senderid)
    lobby = Lobby.get_lobby!(state.lobby_id)

    messages = Teiserver.Coordinator.CoordinatorLib.help(user, lobby.founder_id == senderid)
    |> String.split("\n")

    ConsulServer.say_command(cmd, state)
    Coordinator.send_to_user(senderid, messages)
    state
  end

  def handle_command(%{command: "splitlobby", senderid: senderid} = cmd, %{split: nil} = state) do
    sender_name = User.get_username(senderid)
    LobbyChat.sayex(state.coordinator_id, "#{sender_name} is moving to a new lobby, to follow them say $y. If you want to follow someone else then say $follow <name> and you will follow that user. The split will take place in #{round(@split_delay/1_000)} seconds, you can change your mind at any time. Say $n to cancel your decision and stay here.", state.lobby_id)

    LobbyChat.sayprivateex(state.coordinator_id, senderid, "Splitlobby sequence started. If you stay in this lobby you will be moved to a random empty lobby. If you choose a lobby yourself then anybody ", state.lobby_id)

    split_uuid = UUID.uuid4()

    new_split = %{
      split_uuid: split_uuid,
      first_splitter_id: senderid,
      splitters: %{}
    }

    Logger.info("Started split lobby #{Kernel.inspect new_split}")

    :timer.send_after(@split_delay, {:do_split, split_uuid})
    ConsulServer.say_command(cmd, state)
    %{state | split: new_split}
  end

  def handle_command(%{command: "splitlobby", senderid: senderid} = _cmd, state) do
    LobbyChat.sayprivateex(state.coordinator_id, senderid, "A split is already underway, you cannot start a new one yet", state.lobbyid)
    state
  end

  # Split commands for when there is no split happening
  def handle_command(%{command: "y"}, %{split: nil} = state), do: state
  def handle_command(%{command: "n"}, %{split: nil} = state), do: state
  def handle_command(%{command: "follow"}, %{split: nil} = state), do: state

  # And for when it is
  def handle_command(%{command: "n", senderid: senderid} = cmd, state) do
    Logger.info("Split.n from #{senderid}")

    new_splitters = Map.delete(state.split.splitters, senderid)
    new_split = %{state.split | splitters: new_splitters}
    ConsulServer.say_command(cmd, state)
    %{state | split: new_split}
  end

  def handle_command(%{command: "y", senderid: senderid} = cmd, state) do
    Logger.info("Split.y from #{senderid}")

    new_splitters = Map.put(state.split.splitters, senderid, true)
    new_split = %{state.split | splitters: new_splitters}
    ConsulServer.say_command(cmd, state)
    %{state | split: new_split}
  end

  def handle_command(%{command: "follow", remaining: target, senderid: senderid} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      player_id ->
        Logger.info("Split.follow from #{senderid}")

        new_splitters = if player_id == state.split.first_splitter_id do
          Map.put(state.split.splitters, senderid, true)
        else
          Map.put(state.split.splitters, senderid, player_id)
        end

        new_split = %{state.split | splitters: new_splitters}
        ConsulServer.say_command(cmd, state)
        %{state | split: new_split}
    end
  end

  def handle_command(%{command: "joinq", senderid: senderid} = cmd, state) do
    case Client.get_client_by_id(senderid) do
      %{player: true} ->
        LobbyChat.sayprivateex(state.coordinator_id, senderid, "You are already a player, you can't join the queue!", state.lobby_id)
        state
      _ ->
        new_state = case Enum.member?(state.join_queue, senderid) do
          false ->
            new_queue = state.join_queue ++ [senderid]
            pos = get_queue_position(new_queue, senderid) + 1
            LobbyChat.sayprivateex(state.coordinator_id, senderid, "You are now in the join-queue at position #{pos}", state.lobby_id)

            %{state | join_queue: new_queue}
          true ->
            pos = get_queue_position(state.join_queue, senderid) + 1
            LobbyChat.sayprivateex(state.coordinator_id, senderid, "You were already in the join-queue at position #{pos}", state.lobby_id)
            state
        end

        ConsulServer.say_command(cmd, new_state)
    end
  end

  def handle_command(%{command: "leaveq", senderid: senderid} = cmd, state) do
    new_queue = List.delete(state.join_queue, senderid)
    new_state = %{state | join_queue: new_queue}

    LobbyChat.sayprivateex(state.coordinator_id, senderid, "You have been removed from the join queue", state.lobby_id)
    ConsulServer.say_command(cmd, new_state)
  end


  #################### Boss
  def handle_command(%{command: "gatekeeper", remaining: mode} = cmd, state) do
    state = case mode do
      "friends" ->
        %{state | gatekeeper: :friends}
      "friendsplay" ->
        %{state | gatekeeper: :friendsplay}
      "clan" ->
        %{state | gatekeeper: :clan}
      "default" ->
        %{state | gatekeeper: :default}
      _ ->
        state
    end
    ConsulServer.say_command(cmd, state)
  end

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


  #################### Host and Moderator
  def handle_command(%{command: "leveltoplay", remaining: remaining} = cmd, state) do
    case Integer.parse(remaining |> String.trim) do
      :error ->
        state
      {level, _} ->
        ConsulServer.say_command(cmd, state)
        %{state | level_to_play: level}
    end
  end

  def handle_command(%{command: "leveltospectate", remaining: remaining} = cmd, state) do
    case Integer.parse(remaining |> String.trim) do
      :error ->
        state
      {level, _} ->
        ConsulServer.say_command(cmd, state)
        %{state | level_to_spectate: level}
    end
  end

  def handle_command(%{command: "lock", remaining: remaining} = cmd, state) do
    new_locks = case get_lock(remaining) do
      nil -> state.locks
      lock ->
        ConsulServer.say_command(cmd, state)
        [lock | state.locks] |> Enum.uniq
    end
    %{state | locks: new_locks}
  end

  def handle_command(%{command: "unlock", remaining: remaining} = cmd, state) do
    new_locks = case get_lock(remaining) do
      nil -> state.locks
      lock ->
        ConsulServer.say_command(cmd, state)
        List.delete(state.locks, lock)
    end
    %{state | locks: new_locks}
  end

  def handle_command(%{command: "specunready"} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Client.get_client_by_id(player_id)
      if client.ready == false and client.player == true do
        User.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{player: false})
      end
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: ""} = cmd, state) do
    battle = Lobby.get_lobby!(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Client.get_client_by_id(player_id)
      if client.ready == false and client.player == true do
        User.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
      end
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "makeready", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      player_id ->
        User.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  #################### Moderator only
  # ----------------- General commands
  def handle_command(%{command: "cancelsplit"}, %{split: nil} = state) do
    state
  end

  def handle_command(%{command: "cancelsplit"} = cmd, state) do
    :timer.send_after(50, :cancel_split)
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "dosplit"}, %{split: nil} = state) do
    state
  end

  def handle_command(%{command: "dosplit"} = cmd, %{split: split} = state) do
    :timer.send_after(50, {:do_split, split.split_uuid})
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "rename", remaining: new_name} = cmd, state) do
    Lobby.rename_lobby(state.lobby_id, new_name)
    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "pull", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.force_add_user_to_battle(target_id, state.lobby_id)
        ConsulServer.say_command(cmd, state)
    end
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

  # ----------------- Moderation commands
  def handle_command(cmd = %{command: "modwarn", remaining: remaining}, state) do
    [username, hours | reason] = String.split(remaining, " ")
    reason = Enum.join(reason, " ")

    userid = ConsulServer.get_user(username, state)
    until = "#{hours} hours"

    case Central.Account.ReportLib.perform_action(%{}, "Warn", until) do
      {:ok, expires} ->
        {:ok, _report} =
          Central.Account.create_report(%{
            "location" => "battle-lobby",
            "location_id" => nil,
            "reason" => reason,
            "reporter_id" => cmd.senderid,
            "target_id" => userid,
            "response_text" => reason,
            "response_action" => "Warn",
            "expires" => expires,
            "responder_id" => cmd.senderid
          })

        user = User.get_user_by_id(userid)
        sender = User.get_user_by_id(cmd.senderid)
        LobbyChat.say(state.coordinator_id, "#{user.name} warned for #{hours} hours by #{sender.name}, reason: #{reason}", state.lobby_id)
      _ ->
        LobbyChat.sayprivateex(state.coordinator_id, cmd.senderid, "Unable to find a user by that name", state.lobby_id)
    end

    state
  end

  def handle_command(cmd = %{command: "modmute", remaining: remaining}, state) do
    [username, hours | reason] = String.split(remaining, " ")
    reason = Enum.join(reason, " ")

    userid = ConsulServer.get_user(username, state)
    until = "#{hours} hours"

    case Central.Account.ReportLib.perform_action(%{}, "Mute", until) do
      {:ok, expires} ->
        {:ok, _report} =
          Central.Account.create_report(%{
            "location" => "battle-lobby",
            "location_id" => nil,
            "reason" => reason,
            "reporter_id" => cmd.senderid,
            "target_id" => userid,
            "response_text" => reason,
            "response_action" => "Mute",
            "expires" => expires,
            "responder_id" => cmd.senderid
          })

        user = User.get_user_by_id(userid)
        sender = User.get_user_by_id(cmd.senderid)
        LobbyChat.say(state.coordinator_id, "#{user.name} muted for #{hours} hours by #{sender.name}, reason: #{reason}", state.lobby_id)
      _ ->
        LobbyChat.sayprivateex(state.coordinator_id, cmd.senderid, "Unable to find a user by that name", state.lobby_id)
    end

    state
  end

  def handle_command(cmd = %{command: "modban", remaining: remaining}, state) do
    [username, hours | reason] = String.split(remaining, " ")
    reason = Enum.join(reason, " ")

    userid = ConsulServer.get_user(username, state)
    until = "#{hours} hours"

    case Central.Account.ReportLib.perform_action(%{}, "Ban", until) do
      {:ok, expires} ->
        {:ok, _report} =
          Central.Account.create_report(%{
            "location" => "battle-lobby",
            "location_id" => nil,
            "reason" => reason,
            "reporter_id" => cmd.senderid,
            "target_id" => userid,
            "response_text" => reason,
            "response_action" => "Ban",
            "expires" => expires,
            "responder_id" => cmd.senderid
        })

        user = User.get_user_by_id(userid)
        sender = User.get_user_by_id(cmd.senderid)
        LobbyChat.say(state.coordinator_id, "#{user.name} banned for #{hours} hours by #{sender.name}, reason: #{reason}", state.lobby_id)
      _ ->
        LobbyChat.sayprivateex(state.coordinator_id, cmd.senderid, "Unable to find a user by that name", state.lobby_id)
    end

    state
  end

  def handle_command(%{command: "speclock", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        state
      target_id ->
        ban = new_ban(%{level: :spectator, by: cmd.senderid}, state)
        new_bans = Map.put(state.bans, target_id, ban)

        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
    end
  end

  def handle_command(%{command: "forceplay", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        state
      target_id ->
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: true, ready: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "timeout", remaining: target} = cmd, state) do
    [target | reason_list] = String.split(target, " ")
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        reason = if reason_list == [], do: "You have been given a timeout on the naughty step", else: Enum.join(reason_list, " ")
        timeout = new_timeout(%{level: :banned, by: cmd.senderid, reason: reason}, state)
        new_timeouts = Map.put(state.timeouts, target_id, timeout)

        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)

        %{state | timeouts: new_timeouts}
        |> ConsulServer.broadcast_update("timeout")
    end
  end

  def handle_command(%{command: "lobbykick", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "lobbyban", remaining: target} = cmd, state) do
    [target | reason_list] = String.split(target, " ")
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        reason = if reason_list == [], do: @default_ban_reason, else: Enum.join(reason_list, " ")
        ban = new_ban(%{level: :banned, by: cmd.senderid, reason: reason}, state)
        new_bans = Map.put(state.bans, target_id, ban)

        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("ban")
    end
  end

  def handle_command(%{command: "lobbybanmult", remaining: targets} = cmd, state) do
    {targets, reason} = case String.split(targets, "!!") do
      [t] -> {t, @default_ban_reason}
      [t, r | _] -> {t, String.trim(r)}
    end
    ConsulServer.say_command(cmd, state)

    String.split(targets, " ")
    |> Enum.reduce(state, fn (target, acc) ->
      case ConsulServer.get_user(target, acc) do
        nil ->
          acc
        target_id ->
          ban = new_ban(%{level: :banned, by: cmd.senderid, reason: reason}, acc)
          new_bans = Map.put(acc.bans, target_id, ban)
          Lobby.kick_user_from_battle(target_id, acc.lobby_id)

          %{acc | bans: new_bans}
          |> ConsulServer.broadcast_update("ban")
      end
    end)
  end

  def handle_command(%{command: "unban", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        new_bans = Map.drop(state.bans, [target_id])
        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("unban")
    end
  end

  # This is here to make tests easier to run, it's not expected you'll use this and it's not in the docs
  def handle_command(%{command: "forcespec", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        ban = new_ban(%{level: :spectator, by: cmd.senderid, reason: "forcespec"}, state)
        new_bans = Map.put(state.bans, target_id, ban)

        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("ban")
    end
  end


  def handle_command(%{command: "reset"} = _cmd, state) do
    ConsulServer.empty_state(state.lobby_id)
    |> ConsulServer.broadcast_update("reset")
  end

  #################### Internal commands
  # Would need to be sent by internal since battlestatus isn't part of the command queue
  def handle_command(%{command: "change-battlestatus", remaining: target_id, status: new_status}, state) do
    Lobby.force_change_client(state.coordinator_id, target_id, new_status)
    state
  end

  def handle_command(cmd, state) do
    if Map.has_key?(cmd, :raw) do
      LobbyChat.do_say(cmd.senderid, cmd.raw, state.lobby_id)
    else
      Logger.error("No handler in consul_server for command #{Kernel.inspect cmd}")
    end
    state
  end

  defp new_ban(data, state) do
    Map.merge(%{
      by: state.coordinator_id,
      reason: @default_ban_reason,
      # :player | :spectator | :banned
      level: :banned
    }, data)
  end

  defp new_timeout(data, state) do
    Map.merge(%{
      by: state.coordinator_id,
      reason: "You have been given a timeout on the naughty step",
      # :player | :spectator | :banned
      level: :banned
    }, data)
  end

  @spec get_lock(String.t()) :: atom | nil
  defp get_lock(name) do
    case name |> String.downcase |> String.trim do
      "team" -> :team
      "allyid" -> :allyid
      "player" -> :player
      "spectator" -> :spectator
      "side" ->  :side
      _ -> nil
    end
  end

  defp get_queue_position(queue, userid) do
    case Enum.member?(queue, userid) do
      true ->
        Enum.with_index(queue)
        |> Map.new
        |> Map.get(userid)
      false ->
        -1
    end
  end
end
