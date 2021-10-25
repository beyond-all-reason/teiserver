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
  @spec handle_command(Map.t(), Map.t()) :: Map.t()

  #################### For everybody
  def handle_command(%{command: "status", senderid: senderid} = _cmd, state) do
    locks = state.locks
    |> Enum.map(fn l -> to_string(l) end)
    |> Enum.join(", ")

    status_msg = [
      "Status for battle ##{state.lobby_id}",
      "Locks: #{locks}",
      "Gatekeeper: #{state.gatekeeper}"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "help", senderid: senderid} = _cmd, state) do
    status_msg = [
      "Command list can currently be found at https://github.com/beyond-all-reason/teiserver/blob/master/lib/teiserver/coordinator/coordinator_lib.ex"
    ]
    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "splitlobby", senderid: senderid} = cmd, %{split: nil} = state) do
    sender_name = User.get_username(senderid)
    LobbyChat.sayex(state.coordinator_id, "#{sender_name} is moving to a new lobby, to follow them say $y. If you want to follow someone else then say $follow <name> and you will follow that user. The split will take place in 15 seconds, you can change your mind at any time. Say $n to cancel your decision and stay here.", state.lobby_id)

    LobbyChat.sayprivateex(state.coordinator_id, senderid, "Splitlobby sequence started. If you stay in this lobby you will be moved to a random empty lobby. If you choose a lobby yourself then anybody ", state.lobby_id)

    split_uuid = UUID.uuid4()

    new_split = %{
      split_uuid: split_uuid,
      first_splitter_id: senderid,
      splitters: %{}
    }

    Logger.warn("Started split lobby #{Kernel.inspect new_split}")

    :timer.send_after(20_000, {:do_split, split_uuid})
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
    Logger.warn("Split.n from #{senderid}")

    new_splitters = Map.delete(state.split.splitters, senderid)
    new_split = %{state.split | splitters: new_splitters}
    ConsulServer.say_command(cmd, state)
    %{state | split: new_split}
  end

  def handle_command(%{command: "y", senderid: senderid} = cmd, state) do
    Logger.warn("Split.y from #{senderid}")

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
        Logger.warn("Split.follow from #{senderid}")

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

  #################### Host and Moderator
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
    state
  end

  def handle_command(%{command: "dosplit"}, %{split: nil} = state) do
    state
  end

  def handle_command(%{command: "dosplit"} = cmd, %{split: split} = state) do
    :timer.send_after(50, {:do_split, split.split_uuid})
    ConsulServer.say_command(cmd, state)
    state
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
            "response_text" => "instant-action",
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
            "response_text" => "instant-action",
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
            "response_text" => "instant-action",
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

  def handle_command(%{command: "lobbyban", remaining: target} = cmd, state) do
    [target | reason_list] = String.split(target, " ")
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)
      target_id ->
        reason = if reason_list == [], do: "None given", else: Enum.join(reason_list, " ")
        ban = new_ban(%{level: :banned, by: cmd.senderid, reason: reason}, state)
        new_bans = Map.put(state.bans, target_id, ban)

        Lobby.kick_user_from_battle(target_id, state.lobby_id)

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("ban")
    end
  end

  def handle_command(%{command: "lobbybanmult", remaining: targets} = cmd, state) do
    ConsulServer.say_command(cmd, state)

    String.split(targets, " ")
    |> Enum.reduce(state, fn (target, acc) ->
      case ConsulServer.get_user(target, acc) do
        nil ->
          acc
        target_id ->
          ban = new_ban(%{level: :banned, by: cmd.senderid}, acc)
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
        Lobby.force_change_client(state.coordinator_id, target_id, %{player: false})
        ConsulServer.say_command(cmd, state)
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
      reason: "None given",
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
end
