defmodule Teiserver.Protocols.SpringProtocol do
  @moduledoc """
  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Regex
  alias Teiserver.Client
  alias Teiserver.Battle
  alias Teiserver.Room
  alias Teiserver.User
  alias Phoenix.PubSub

  # Setup stuff TODO
  # REGISTER

  # Other TODO
  # CONFIRMAGREEMENT
  # RENAMEACCOUNT
  # CHANGEPASSWORD
  # CHANGEEMAILREQUEST
  # CHANGEEMAIL
  # RESENDVERIFICATION
  # RESETPASSWORDREQUEST
  # RESETPASSWORD
  # CHANNELS
  # HANDICAP
  # KICKFROMBATTLE
  # FORECTEAMNO
  # FORCEALLYNO
  # FORCETEAMCOLOR
  # FORCESPECTATORMODE
  # DISABLEUNITS
  # ENABLEUNITS
  # ENABLEALLUNITS
  # RING
  # ADDBOT
  # UPDATEBOT
  # ADDSTARTRECT
  # REMOVESTARTRECT
  # SETSCRIPTTAGS
  # REMOVESCRIPTTAGS
  # LISTCOMPFLAGS
  # PROMOTE
  
  @motd """
Message of the day
Welcome to Teiserver
"""

  # The welcome message is sent to a client when they first connect
  # to the server
  def welcome(socket, transport) do
    _send("TASSERVER 0.38-33-ga5f3b28 * 8201 0\n", socket, transport, nil)
  end

  # The main entry point for the module and the wrapper around
  # parsing, processing and acting upon a player message
  @spec handle(String.t, Map.t) :: Map.t
  def handle("", state), do: state
  def handle("\r\n", state), do: state
  def handle(data, state) do
    tuple = ~r/^(#[0-9]+ )?([A-Z0-9]+)(.*)?$/
    |> Regex.run(data)
    |> _clean

    case tuple do
      {command, data, msg_id} ->
        do_handle(command, data, %{state | msg_id: msg_id})
      nil ->
        Logger.error("Bad match on command: '#{data}'")
        state
    end
  end

  defp _clean(nil), do: nil
  defp _clean([_, msg_id, command, data]) do
    {command, String.trim(data), String.trim(msg_id)}
  end

  # Specific handlers for different commands
  @spec do_handle(String.t, String.t, Map.t) :: Map.t
  defp do_handle("MYSTATUS", data, state) do
    case Regex.run(~r/([0-9]+)/, data) do
      [_, new_value] ->
        # TODO
        # This is trying to parse it, currently not sure
        # how well this is working so for now
        # not parsing it
        # status
        # |> String.to_integer
        # |> Integer.digits(2)
        # |> Client.create_from_bits(state.client)
        # |> Client.update

        # This just accepts it and updates the client
        new_client = Client.new_status(state.name, new_value)
        %{state | client: new_client}
      nil ->
        Logger.debug("[command:mystatus] bad match on: #{data}")
        state
    end
  end

  # Special handler to allow us to test more easily, it just accepts
  # any login. As soon as we put password checking in place this will
  # stop working
  defp do_handle("LI", username, state) do
    do_handle("LOGIN", "#{username} password 0 * LuaLobby Chobby\t1993717506\t0d04a635e200f308\tb sp", state)
  end

  defp do_handle("LOGIN", data, state) do
    response = case Regex.run(~r/^(\w+) ([a-zA-Z0-9=]+) (0) ([0-9\.\*]+) ([^\t]+)\t([^\t]+)\t([^\t]+)/, data) do
      [_, username, password, _cpu, ip, lobby, user_id, modes] ->
        _ = [username, password, ip, lobby, user_id, modes]
        Logger.debug("[protocol:login] matched #{username}")
        User.try_login(username, password, state)
      nil ->
        {:error, "Invalid details format"}
    end

    case response do
      {:ok, user} ->
        # Login the client
        client = Client.login(user, self(), __MODULE__)

        # Who is online?
        Client.list_client_names()
        |> Enum.each(fn name ->
          user = User.get_user(name)
          reply(:add_user, user, state)
        end)

        Battle.list_battles()
        |> Enum.each(fn b ->
          reply(:battle_opened, b, state)
          reply(:update_battle, b, state)
          reply(:battle_players, b, state)
        end)

        :ok = PubSub.subscribe(Teiserver.PubSub, "user_updates:#{user.name}")
        _send("LOGININFOEND\n", state)
        %{state | client: client, user: user, name: user.name}

      {:error, reason} ->
        Logger.debug("[command:login] denied with reason #{reason}")
        _send("DENIED #{reason}\n", state)
        state
    end
  end
  
  defp do_handle("EXIT", _reason, state) do
    send(self(), :terminate)
    # GenServer.cast(via_tuple(t.id), {:terminate})
    state
  end

  defp do_handle("GETUSERINFO", _, state) do
    # TODO: Actually have this information
    msg = [
      "SERVERMSG Registration date: yesterday\n",
      "SERVERMSG Email address: #{state.name}@#{state.name}.com\n",
      "SERVERMSG Ingame time: xyz hours\n",
    ]
    _send(msg, state)
    state
  end

  # Friend list
  defp do_handle("FRIENDLIST", _, state), do: reply(:friendlist, state.user, state)
  defp do_handle("FRIENDREQUESTLIST", _, state), do: reply(:friendlist_request, state.user, state)

  defp do_handle("ACCEPTFRIENDREQUEST", data, state) do
    [_, username] = String.split(data, "=")
    new_user = User.accept_friend_request(username, state.name)
    %{state | user: new_user}
  end

  defp do_handle("DECLINEFRIENDREQUEST", data, state) do
    [_, username] = String.split(data, "=")
    new_user = User.decline_friend_request(username, state.name)
    %{state | user: new_user}
  end

  defp do_handle("FRIENDREQUEST", data, state) do
    [_, username] = String.split(data, "=")
    User.create_friend_request(state.name, username)
    state
  end

  defp do_handle("IGNORE", data, state) do
    [_, username] = String.split(data, "=")
    User.ignore_user(state.name, username)
    state
  end

  defp do_handle("UNIGNORE", data, state) do
    [_, username] = String.split(data, "=")
    User.unignore_user(state.name, username)
    state
  end

  defp do_handle("IGNORELIST", _, state), do: reply(:ignorelist, state.user, state)

  # Chat related
  defp do_handle("JOIN", data, state) do
    case Regex.run(~r/(\w+)(?:\t)?(\w+)?/, data) do
      [_, room_name] ->
        room = Room.get_room(room_name)
        Room.add_user_to_room(state.name, room_name)
        _send("JOIN #{room_name}\n", state)
        _send("CHANNELTOPIC #{room_name} #{room.author}\n", state)
        members = Enum.join(room.members, " ")
        _send("CLIENTS #{room_name} #{members}\n", state)

        :ok = PubSub.subscribe(Teiserver.PubSub, "room:#{room_name}")
      [_, room_name, _key] ->
        _send("JOINFAILED #{room_name} Locked\n", state)
      _ ->
        _send("JOINFAILED No match for details\n", state)
    end
    state
  end

  defp do_handle("LEAVE", room_name, state) do
    PubSub.unsubscribe Teiserver.PubSub, "room:#{room_name}"
    Room.remove_user_from_room(state.name, room_name)
    state
  end

  defp do_handle("SAY", data, state) do
    case Regex.run(~r/(\w+) (.+)/, data) do
      [_, room_name, msg] ->
        Room.send_message(state.name, room_name, msg)
      _ ->
        nil
    end
    state
  end

  defp do_handle("SAYPRIVATE", data, state) do
    case Regex.run(~r/(\w+) (.+)/, data) do
      [_, to_name, msg] ->
        User.send_direct_message(state.name, to_name, msg)
        _send("SAIDPRIVATE #{to_name} #{msg}\n", state)
      _ ->
        nil
    end
    state
  end

  # Battles
  defp do_handle("JOINBATTLE", data, state) do
    response = case Regex.run(~r/^(\S+) (\S+) (\S+)$/, data) do
      [_, battleid, _password, _script_password] ->
        battle = battleid
        |> String.to_integer
        |> Battle.get_battle
        {:accepted, battle}
      nil ->
        {:denied, "Invalid details"}
    end

    case response do
      {:accepted, nil} ->
        Logger.debug("[command:joinbattle] failed as could not find battle")
        _send("JOINBATTLEFAILED battle_not_found\n", state)
        state

      {:accepted, battle} ->
        Logger.debug("[command:joinbattle] success")
        Battle.add_user_to_battle(state.name, battle.id)
        PubSub.subscribe Teiserver.PubSub, "battle_updates:#{battle.id}"
        reply(:join_battle, battle, state)
        reply(:battle_settings, battle, state)

        battle.players
        |> Enum.each(fn username ->
          client = Client.get_client(username)
          reply(:battlestatus, [username, client.battlestatus, client.team_colour], state)
        end)

        reply(:battlestatus, [state.name, 0, 0], state)

        battle.start_rectangles
        |> Enum.each(fn r ->
          reply(:start_rectangle, r, state)
        end)
        _send("REQUESTBATTLESTATUS\n", state)

        # I think this is sent by SPADS but for now we're going to fake it
        _send("SAIDBATTLEEX #{battle.founder} Hi #{state.name}! Current battle type is faked_team.\n", state)

        new_client = Map.put(state.client, :battle_id, battle.id)
        |> Client.update

        %{state | client: new_client}

      {:denied, reason} ->
        Logger.debug("[command:joinbattle] denied with reason #{reason}")
        _send("JOINBATTLEFAILED #{reason}\n", state)
        state
    end
  end

  defp do_handle("SAYBATTLE", msg, state) do
    Battle.say(state.name, msg, state.client.battle_id)
    state
  end

  defp do_handle("LEAVEBATTLE", _, state) do
    PubSub.unsubscribe Teiserver.PubSub, "battle_updates:#{state.client.battle_id}"
    reply(:remove_user_from_battle, {state.name, state.client.battle_id}, state)
    new_client = Client.leave_battle(state.name)
    %{state | client: new_client}
  end

  defp do_handle("MYBATTLESTATUS", data, state) do
    new_client = case Regex.run(~r/(\S+) (.+)/, data) do
      [_, battlestatus, team_colour] ->
        Client.new_battlestatus(state.name, battlestatus, team_colour)
      _ ->
        state.client
    end
    Map.put(state, :client, new_client)
  end

  # MISC
  defp do_handle("PING", _, state) do
    _send("PONG\n", state)
    state
  end

  # Not handled cacther
  defp do_handle(nil, _, state), do: state
  defp do_handle(match, _, state) do
    Logger.error("No match  #{match}")
    _send("ERR - No match\n", state)
    state
  end

  
  # Reply commands, these are things we are sending to the client
  # based on messages they sent us
  @spec reply(Atom.t, nil | String.t | Tuple.t | List.t, Map.t) :: Map.t
  def reply(reply_type, data, state) do
    msg = do_reply(reply_type, data)
    _send(msg, state)
    state
  end

  # Two argument version of the above, just means the data is nil
  @spec reply(Atom.t, Map.t) :: Map.t
  def reply(reply_type, state), do: reply(reply_type, nil, state)

  @spec do_reply(Atom.t, String.t | List.t) :: String.t
  defp do_reply(:login_accepted, user) do
    "ACCEPTED #{user}\n"
  end

  defp do_reply(:motd, nil) do
    @motd
    |> String.split("\n")
    |> Enum.map(fn m -> "MOTD #{m}\n" end)
    |> Enum.join("")
  end

  defp do_reply(:add_user, user) do
    "ADDUSER #{user.name} #{user.country} #{user.id}\t#{user.lobbyid}\n"
  end

  defp do_reply(:clientstatus, client) do
    "CLIENTSTATUS #{client.name}\t#{client.status}"
  end

  defp do_reply(:friendlist, user) do
    friends = user.friends
    |> Enum.map(fn f ->
      "FRIENDLIST userName=#{f}\n"
    end)

    ["FRIENDLISTBEGIN\n"] ++ friends ++ ["FRIENDLISTEND\n"]
    |> Enum.join("")
  end

  defp do_reply(:friendlist_request, user) do
    requests = user.friend_requests
    |> Enum.map(fn f ->
      "FRIENDREQUESTLIST userName=#{f}\n"
    end)

    ["FRIENDREQUESTLISTBEGIN\n"] ++ requests ++ ["FRIENDREQUESTLISTEND\n"]
    |> Enum.join("")
  end

  defp do_reply(:ignorelist, user) do
    ignored = user.ignored
    |> Enum.map(fn f ->
      "IGNORELIST userName=#{f}\n"
    end)

    ["IGNORELISTBEGIN\n"] ++ ignored ++ ["IGNORELISTEND\n"]
    |> Enum.join("")
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#BATTLEOPENED:server
  defp do_reply(:battle_opened, battle) do
    type = case battle.type do
      :normal -> 0
      :replay -> 1
    end
    nattype = case battle.nattype do
      :none -> 0
      :holepunch -> 1
      :fixed -> 2
    end
    passworded = if battle.passworded, do: 1, else: 0

    "BATTLEOPENED #{battle.id} #{type} #{nattype} #{battle.founder} #{battle.ip} #{battle.port} #{battle.max_players} #{passworded} #{battle.rank} #{battle.map_hash} #{battle.engine_name}\t#{battle.engine_version}\t#{battle.map_name}\t#{battle.title}\t#{battle.game_name}\ttest-15386-5c98cfa\n"
  end

  defp do_reply(:update_battle, battle) do
    locked = (battle.locked == 1)
    "UPDATEBATTLEINFO #{battle.id} #{Enum.count(battle.spectators)} #{locked} #{battle.map_hash} #{battle.map_name}\n"
  end

  defp do_reply(:join_battle, battle) do
    "JOINBATTLE #{battle.id} #{battle.hash_code}\n"
  end

  defp do_reply(:start_rectangle, [team, left, top, right, bottom]) do
    "ADDSTARTRECT #{team} #{left} #{top} #{right} #{bottom}\n"
  end

  defp do_reply(:battle_settings, battle) do
    tags = battle.tags
    |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
    |> Enum.join("\t")

    "SETSCRIPTTAGS " <> tags <> "\n"
  end

  defp do_reply(:battle_players, battle) do
    battle.players
    |> Enum.map(fn p -> "JOINEDBATTLE #{battle.id} #{p}\n" end)
  end

  # Client
  defp do_reply(:new_clientstatus, [username, status]) do
    "CLIENTSTATUS #{username} #{status}\n"
  end

  defp do_reply(:battlestatus, [username, battlestatus, team_colour]) do
    "CLIENTBATTLESTATUS #{username} #{battlestatus} #{team_colour}\n"
  end

  defp do_reply(:logged_in_client, username) do
    user = User.get_user(username)
    do_reply(:add_user, user)
  end

  # Chat
  defp do_reply(:direct_message, {from, msg, state_user}) do
    if from not in state_user.ignored do
      "SAIDPRIVATE #{from} #{msg}\n"
    end
  end

  defp do_reply(:chat_message, {from, room_name, msg, state_user}) do
    if from not in state_user.ignored do
      "SAID #{room_name} #{from} #{msg}\n"
    end
  end

  defp do_reply(:add_user_to_room, {username, room_name}) do
    "JOINED #{room_name} #{username}\n"
  end

  # Battle
  defp do_reply(:remove_user_from_room, {username, room_name}) do
    "LEFT #{room_name} #{username}\n"
  end

  defp do_reply(:add_user_to_battle, {username, battleid}) do
    "JOINEDBATTLE #{battleid} #{username}\n"
  end

  defp do_reply(:remove_user_from_battle, {username, battleid}) do
    "LEFTBATTLE #{battleid} #{username}\n"
  end

  defp do_reply(:battle_message, {username, msg, _battle_id}) do
    "SAIDBATTLE #{username} #{msg}\n"
  end

  defp do_reply(:battle_saidex, {username, msg, _battle_id}) do
    "SAIDBATTLEEX #{username} #{msg}\n"
  end

  # Sends a message to the client. The function takes into account message ID and well warn if a message without a newline ending is sent.
  defp _send(msg, state) do
    _send(msg, state.socket, state.transport, state.msg_id)
  end

  defp _send(nil, _, _, _), do: nil
  defp _send("", _, _, _), do: nil
  defp _send([], _, _, _), do: nil
  defp _send(msg, socket, transport, msg_id) when is_list(msg) do
    _send(Enum.join(msg, ""), socket, transport, msg_id)
  end
  defp _send(msg, socket, transport, msg_id) do
    # If no line return at the end we should warn about that
    # I've made the mistake of forgetting it and wondering
    # why stuff wasn't working so it's staying here
    if not String.ends_with?(msg, "\n") do
      Logger.warn("Attempting to send message without newline at the end - #{msg}")
    end

    msg = if msg_id != "" and msg_id != nil do
      msg
      |> String.trim()
      |> String.split("\n")
      |> Enum.map(fn m -> "#{msg_id} #{m}\n" end)
      |> Enum.join("")
    else
      msg
    end

    Logger.debug("--> #{msg}")
    transport.send(socket, msg)
  end
end
