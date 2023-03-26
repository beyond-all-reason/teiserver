defmodule Teiserver.Protocols.SpringOut do
  @moduledoc """
  Out component of the Spring protocol.

  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Phoenix.PubSub
  alias Teiserver.{User, Client, Room, Battle, Coordinator}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Protocols.Spring
  alias Teiserver.Protocols.Spring.{BattleOut}
  alias Teiserver.Data.Types, as: T

  @motd """
  Message of the day
  Welcome to Teiserver
  Connect on port 8201 for TLS
  ---------
  """

  @compflags "sp teiserver matchmaking token-auth tachyon"

  @spec reply(atom(), nil | String.t() | tuple() | list(), String.t(), map) :: map
  def reply(reply_cmd, data, msg_id, state) do
    reply(:spring, reply_cmd, data, msg_id, state)
  end

  @spec reply(atom(), atom(), nil | String.t() | tuple() | list(), String.t(), map) :: map
  def reply(namespace, reply_cmd, data, msg_id, state) do
    msg =
      case namespace do
        :battle -> BattleOut.do_reply(reply_cmd, data, state)
        :spring -> do_reply(reply_cmd, data)
      end

    if Application.get_env(:central, Teiserver)[:extra_logging] == true or state.print_server_messages do
      if is_list(msg) do
        msg
        |> Enum.each(fn m ->
          Logger.info("--> #{state.username}: #{Spring.format_log(m)}")
        end)
      else
        Logger.info("--> #{state.username}: #{Spring.format_log(msg)}")
      end
    end

    if Enum.member?([nil, ""], msg) do
      state
    else
      prep_to_send(msg, msg_id, state)
    end
  end

  @spec do_reply(atom(), String.t() | list()) :: String.t() | List.t()
  defp do_reply(:login_accepted, user) do
    "ACCEPTED #{user}\n"
  end

  defp do_reply(:denied, reason) do
    "DENIED #{reason}\n"
  end

  defp do_reply(:motd, nil) do
    @motd
    |> String.split("\n")
    |> Enum.map_join("", fn m -> "MOTD #{m}\n" end)
  end

  defp do_reply(:welcome, nil) do
    "TASSERVER 0.38-33-ga5f3b28 * 8201 0\n"
  end

  defp do_reply(:compflags, nil) do
    "COMPFLAGS #{@compflags}\n"
  end

  defp do_reply(:pong, nil) do
    "PONG\n"
  end

  defp do_reply(:login_end, nil) do
    "LOGININFOEND\n"
  end

  defp do_reply(:agreement, nil) do
    agreement_rows = Application.get_env(:central, Teiserver)[:user_agreement]
    |> String.split("\n")
    |> Enum.map(fn s -> "AGREEMENT #{s}" end)
    |> Enum.join("\n")

    [agreement_rows <> "\n"] ++ [
      "AGREEMENT \n",
      "AGREEMENTEND\n"
    ]
  end

  defp do_reply(:user_token, {email, token}) do
    "s.user.user_token #{email}\t#{token}\n"
  end

  defp do_reply(:okay, cmd) do
    if cmd do
      "OK cmd=#{cmd}\n"
    else
      "OK\n"
    end
  end

  defp do_reply(:no, {cmd, msg}) do
    "NO cmd=#{cmd}\t#{msg}\n"
  end

  defp do_reply(:no, cmd) do
    "NO cmd=#{cmd}\n"
  end

  defp do_reply(:list_battles, lobby_ids) do
    ids =
      lobby_ids
      |> Enum.join("\t")

    "s.battles.id_list #{ids}\n"
  end

  defp do_reply(:add_user, nil), do: ""

  defp do_reply(:add_user, client) do
    "ADDUSER #{client.name} #{client.country} #{client.userid} #{client.lobby_client}\n"
  end

  defp do_reply(:friendlist, nil), do: "FRIENDLISTBEGIN\FRIENDLISTEND\n"
  defp do_reply(:friendlist, user) do
    friends =
      user.friends
      |> Enum.map(fn f ->
        name = User.get_username(f)
        if name do
          "FRIENDLIST userName=#{name}\n"
        end
      end)
      |> Enum.reject(fn s -> s == nil end)

    (["FRIENDLISTBEGIN\n"] ++ friends ++ ["FRIENDLISTEND\n"])
    |> Enum.join("")
  end

  defp do_reply(:friendlist_request, nil), do: "FRIENDLISTBEGIN\nFRIENDLISTEND\n"
  defp do_reply(:friendlist_request, user) do
    requests =
      user.friend_requests
      |> Enum.map(fn f ->
        name = User.get_username(f)
        "FRIENDREQUESTLIST userName=#{name}\n"
      end)

    (["FRIENDREQUESTLISTBEGIN\n"] ++ requests ++ ["FRIENDREQUESTLISTEND\n"])
    |> Enum.join("")
  end

  defp do_reply(:ignorelist, nil), do: "IGNORELISTBEGIN\IGNORELISTEND\n"
  defp do_reply(:ignorelist, user) do
    ignored =
      user.ignored
      |> Enum.map(fn f ->
        name = User.get_username(f)
        "IGNORELIST userName=#{name}\n"
      end)

    (["IGNORELISTBEGIN\n"] ++ ignored ++ ["IGNORELISTEND\n"])
    |> Enum.join("")
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#BATTLEOPENED:server
  defp do_reply(:battle_opened, battle) when is_map(battle) do
    type =
      case battle.type do
        "normal" -> 0
        "replay" -> 1
      end

    nattype =
      case battle.nattype do
        "none" -> 0
        "holepunch" -> 1
        "fixed" -> 2
        _ -> 0
      end

    passworded = if battle.password == nil, do: 0, else: 1

    "BATTLEOPENED #{battle.id} #{type} #{nattype} #{battle.founder_name} #{battle.ip} #{
      battle.port
    } #{battle.max_players} #{passworded} #{battle.rank} #{battle.map_hash} #{battle.engine_name}\t#{
      battle.engine_version
    }\t#{battle.map_name}\t#{battle.name}\t#{battle.game_name}\n"
  end

  defp do_reply(:battle_opened, lobby_id) when is_integer(lobby_id) do
    do_reply(:battle_opened, Lobby.get_lobby(lobby_id))
  end

  defp do_reply(:battle_opened, _lobby_id) do
    ""
  end

  defp do_reply(:open_battle_success, lobby_id) do
    "OPENBATTLE #{lobby_id}\n"
  end

  defp do_reply(:open_battle_failure, reason) do
    "OPENBATTLEFAILED #{reason}\n"
  end

  defp do_reply(:battle_closed, lobby_id) do
    "BATTLECLOSED #{lobby_id}\n"
  end

  defp do_reply(:request_battle_status, nil) do
    "REQUESTBATTLESTATUS\n"
  end

  defp do_reply(:update_battle, lobby) when is_map(lobby) do
    # spectator_count = Battle.get_lobby_spectator_count(lobby.id) + 1
    spectator_count = lobby.spectator_count
    locked = if lobby.locked, do: "1", else: "0"

    "UPDATEBATTLEINFO #{lobby.id} #{spectator_count} #{locked} #{lobby.map_hash} #{
      lobby.map_name}\n"
  end

  defp do_reply(:update_battle, lobby_id) when is_integer(lobby_id) do
    do_reply(:update_battle, Battle.get_lobby(lobby_id))
  end

  defp do_reply(:update_battle, _), do: ""

  defp do_reply(:join_battle_success, battle) do
    "JOINBATTLE #{battle.id} #{battle.game_hash}\n"
  end

  defp do_reply(:join_battle_failure, reason) do
    "JOINBATTLEFAILED #{reason}\n"
  end

  defp do_reply(:add_start_rectangle, {team, %{shape: "rectangle"} = definition}) do
    "ADDSTARTRECT #{team} #{definition.x1} #{definition.y1} #{definition.x2} #{definition.y2}\n"
  end

  defp do_reply(:remove_start_rectangle, team) do
    "REMOVESTARTRECT #{team}\n"
  end

  defp do_reply(:add_script_tags, tags) do
    tags =
      tags
      |> Enum.map(fn {key, value} -> "#{key}=#{value}" end)
      |> Enum.join("\t")

    "SETSCRIPTTAGS " <> tags <> "\n"
  end

  defp do_reply(:remove_script_tags, keys) do
    keys = keys
      |> Enum.reject(fn k -> Enum.member?(["", " "], k) end)

    "REMOVESCRIPTTAGS " <> Enum.join(keys, "\t") <> "\n"
  end

  defp do_reply(:enable_all_units, _units) do
    "ENABLEALLUNITS\n"
  end

  defp do_reply(:enable_units, units) do
    "ENABLEUNITS " <> Enum.join(units, " ") <> "\n"
  end

  defp do_reply(:disable_units, units) do
    "DISABLEUNITS " <> Enum.join(units, " ") <> "\n"
  end

  defp do_reply(:add_bot_to_battle, {lobby_id, bot}) do
    status = Spring.create_battle_status(bot)

    "ADDBOT #{lobby_id} #{bot.name} #{bot.owner_name} #{status} #{bot.team_colour} #{bot.ai_dll}\n"
  end

  defp do_reply(:remove_bot_from_battle, {lobby_id, botname}) do
    "REMOVEBOT #{lobby_id} #{botname}\n"
  end

  defp do_reply(:update_bot, {lobby_id, bot}) do
    status = Spring.create_battle_status(bot)
    "UPDATEBOT #{lobby_id} #{bot.name} #{status} #{bot.team_colour}\n"
  end

  # Client
  defp do_reply(:registration_accepted, nil) do
    "REGISTRATIONACCEPTED\n"
  end

  defp do_reply(:registration_denied, reason) do
    "REGISTRATIONDENIED #{reason}\n"
  end

  defp do_reply(:client_status, nil), do: ""
  defp do_reply(:client_status, client) do
    status = Spring.create_client_status(client)
    "CLIENTSTATUS #{client.name} #{status}\n"
  end

  defp do_reply(:client_battlestatus, nil), do: nil

  defp do_reply(:client_battlestatus, client) do
    status = Spring.create_battle_status(client)
    "CLIENTBATTLESTATUS #{client.name} #{status} #{client.team_colour}\n"
  end

  # It's possible for a user to log in and then out really fast and cause issues with this
  defp do_reply(:user_logged_in, nil), do: nil
  defp do_reply(:user_logged_in, client) do
    [
      do_reply(:add_user, client),
      do_reply(:client_status, client)
    ]
  end

  defp do_reply(:user_logged_out, {_userid, username}) do
    "REMOVEUSER #{username}\n"
  end

  # Commands
  defp do_reply(:ring, {ringer_id, state_userid}) do
    user = User.get_user_by_id(state_userid)
    ringer_user = User.get_user_by_id(ringer_id)
    if ringer_id not in (user.ignored || []) or ringer_user.moderator == true or User.is_bot?(ringer_user) == true do
      ringer_name = User.get_username(ringer_id)
      "RING #{ringer_name}\n"
    end
  end

  # Request password reset
  defp do_reply(:reset_password_actual_accepted, nil) do
    "RESETPASSWORDACCEPTED\n"
  end

  defp do_reply(:reset_password_actual_denied, reason) do
    "RESETPASSWORDDENIED #{reason}\n"
  end

  defp do_reply(:reset_password_request_accepted, nil) do
    "RESETPASSWORDREQUESTACCEPTED\n"
  end

  defp do_reply(:reset_password_request_denied, reason) do
    "RESETPASSWORDREQUESTDENIED #{reason}\n"
  end

  # Email change request
  defp do_reply(:change_email_accepted, nil) do
    "CHANGEEMAILACCEPTED\n"
  end

  defp do_reply(:change_email_denied, reason) do
    "CHANGEEMAILDENIED #{reason}\n"
  end

  defp do_reply(:change_email_request_accepted, nil) do
    "CHANGEEMAILREQUESTACCEPTED\n"
  end

  # SLDB
  defp do_reply(:user_ip, {username, ip}) do
    "#{username} is currently bound to #{ip}\n"
  end

  defp do_reply(:user_id, {username, lobby_hash, springid}) do
    "The ID for #{username} is #{lobby_hash} #{springid}\n"
  end

  defp do_reply(:change_email_request_denied, reason) do
    "CHANGEEMAILREQUESTDENIED #{reason}\n"
  end

  # Chat
  defp do_reply(:join_success, room_name) do
    "JOIN #{room_name}\n"
  end

  defp do_reply(:join_failure, {room_name, reason}) do
    "JOINFAILED #{room_name}\t#{reason}\n"
  end

  defp do_reply(:left_room, {username, room_name}) do
    "LEFT #{room_name} #{username}\n"
  end

  defp do_reply(:channel_topic, {room_name, author_name}) do
    "CHANNELTOPIC #{room_name} #{author_name}\n"
  end

  defp do_reply(:channel_members, {members, room_name}) do
    "CLIENTS #{room_name} #{members}\n"
  end

  defp do_reply(:list_channels, nil) do
    channels =
      Room.list_rooms()
      |> Enum.map(fn room ->
        "CHANNEL #{room.name} #{Enum.count(room.members)}\n"
      end)

    (["CHANNELS\n"] ++ channels ++ ["ENDOFCHANNELS\n"])
    |> Enum.join("")
  end

  defp do_reply(:sent_direct_message, {to_id, msg}) do
    to_name = User.get_username(to_id)
    "SAYPRIVATE #{to_name} #{msg}\n"
  end

  defp do_reply(:direct_message, {from_id, messages, state_user}) when is_list(messages) do
    from_user = User.get_user_by_id(from_id)
    if from_id not in (state_user.ignored || []) or from_user.moderator == true do
      from_name = User.get_username(from_id)
      messages
      |> Enum.map(fn msg ->
        "SAIDPRIVATE #{from_name} #{msg}\n"
      end)
      |> Enum.join("")
    end
  end

  defp do_reply(:direct_message, {from_id, msg, state_user}) do
    do_reply(:direct_message, {from_id, [msg], state_user})
  end

  defp do_reply(:chat_message, {from_id, room_name, messages, state_user}) when is_list(messages) do
    from_user = User.get_user_by_id(from_id)
    if from_id not in (state_user.ignored || []) or from_user.moderator == true or User.is_bot?(from_user) == true do
      from_name = User.get_username(from_id)
      messages
      |> Enum.map(fn msg ->
        "SAID #{room_name} #{from_name} #{msg}\n"
      end)
      |> Enum.join("")
    end
  end

  defp do_reply(:chat_message, {from_id, room_name, msg, state_user}) do
    do_reply(:chat_message, {from_id, room_name, [msg], state_user})
  end

  defp do_reply(:chat_message_ex, {from_id, room_name, messages, state_user}) when is_list(messages) do
    from_user = User.get_user_by_id(from_id)
    if from_id not in (state_user.ignored || []) or from_user.moderator == true or User.is_bot?(from_user) == true do
      from_name = User.get_username(from_id)
      messages
      |> Enum.map(fn msg ->
        "SAIDEX #{room_name} #{from_name} #{msg}\n"
      end)
      |> Enum.join("")
    end
  end

  defp do_reply(:chat_message_ex, {from_id, room_name, msg, state_user}) do
    do_reply(:chat_message_ex, {from_id, room_name, [msg], state_user})
  end

  defp do_reply(:add_user_to_room, {userid, room_name}) do
    username = User.get_username(userid)
    "JOINED #{room_name} #{username}\n"
  end

  # Battle
  defp do_reply(:request_user_join_lobby, userid) do
    client = Client.get_client_by_id(userid)
    "JOINBATTLEREQUEST #{client.name} #{client.ip}\n"
  end

  defp do_reply(:remove_user_from_room, {userid, room_name}) do
    username = User.get_username(userid)
    "LEFT #{room_name} #{username}\n"
  end

  defp do_reply(:add_user_to_battle, {userid, lobby_id, nil}) do
    username = User.get_username(userid)
    "JOINEDBATTLE #{lobby_id} #{username}\n"
  end

  defp do_reply(:add_user_to_battle, {userid, lobby_id, script_password}) do
    username = User.get_username(userid)
    "JOINEDBATTLE #{lobby_id} #{username} #{script_password}\n"
  end

  defp do_reply(:remove_user_from_battle, {userid, lobby_id}) do
    username = User.get_username(userid)
    "LEFTBATTLE #{lobby_id} #{username}\n"
  end

  defp do_reply(:kick_user_from_battle, {userid, lobby_id}) do
    username = User.get_username(userid)
    "KICKFROMBATTLE #{lobby_id} #{username}\n"
  end

  defp do_reply(:forcequit_battle, nil) do
    "FORCEQUITBATTLE\n"
  end

  defp do_reply(:battle_message, {sender_id, messages, _lobby_id, state_userid}) when is_list(messages) do
    user = User.get_user_by_id(state_userid)
    if sender_id not in (user.ignored || []) do
      username = User.get_username(sender_id)
      messages
      |> Enum.map(fn msg ->
        "SAIDBATTLE #{username} #{msg}\n"
      end)
      |> Enum.join("")
    end
  end

  defp do_reply(:battle_message, {userid, msg, lobby_id, state_userid}) do
    do_reply(:battle_message, {userid, [msg], lobby_id, state_userid})
  end

  defp do_reply(:battle_message_ex, {sender_id, messages, _lobby_id, state_userid}) when is_list(messages) do
    user = User.get_user_by_id(state_userid)
    if sender_id not in (user.ignored || []) do
      username = User.get_username(sender_id)
      messages
      |> Enum.map(fn msg ->
        "SAIDBATTLEEX #{username} #{msg}\n"
      end)
      |> Enum.join("")
    end
  end

  defp do_reply(:battle_message_ex, {userid, msg, lobby_id, state_userid}) do
    do_reply(:battle_message_ex, {userid, [msg], lobby_id, state_userid})
  end

  defp do_reply(:servermsg, msg) do
    "SERVERMSG #{msg}\n"
  end

  defp do_reply(:disconnect, reason) do
    "s.system.disconnect #{reason}\n"
  end

  defp do_reply(:server_restart, _) do
    "s.system.shutdown\n"
  end

  defp do_reply(:error_log, _) do
    "s.client.errorlog\n"
  end

  # defp do_reply(:tachyon, {namespace, function, data, state}) do
  #   Teiserver.Protocols.Tachyon.V1.TachyonOut.reply(namespace, function, data, state)
  # end

  defp do_reply(atom, data) do
    Logger.error(
      "No reply match in spring_out.ex for atom: #{atom} and data: #{Kernel.inspect(data)}"
    )

    ""
  end

  @spec do_leave_battle(map(), T.lobby_id()) :: map()
  def do_leave_battle(state, lobby_id) do
    PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby_id}")
    state
  end

  @spec do_join_battle(map(), integer(), String.t()) :: map()
  def do_join_battle(state, lobby_id, script_password) do
    lobby = Lobby.get_lobby(lobby_id)

    if lobby do
      Lobby.add_user_to_battle(state.userid, lobby.id, script_password)
      PubSub.unsubscribe(Central.PubSub, "legacy_battle_updates:#{lobby.id}")
      PubSub.subscribe(Central.PubSub, "legacy_battle_updates:#{lobby.id}")

      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby.id}")
      PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{lobby.id}")

      state = reply(:join_battle_success, lobby, nil, state)
      state = reply(:add_user_to_battle, {state.userid, lobby.id, script_password}, nil, state)

      modoptions = Battle.get_modoptions(lobby_id)
      state = reply(:add_script_tags, modoptions, nil, state)

      state = [lobby.founder_id | lobby.players]
        |> Enum.reduce(state, fn (id, temp_state) ->
          client = Client.get_client_by_id(id)
          reply(:client_battlestatus, client, nil, temp_state)
        end)

      state = Battle.get_bots(lobby_id)
        |> Enum.reduce(state, fn {{_botname, bot}, temp_state} ->
          reply(:add_bot_to_battle, {lobby.id, bot}, nil, temp_state)
        end)

      state = lobby.start_areas
        |> Enum.reduce(state, fn {{team, r}, temp_state} ->
          reply(:add_start_rectangle, {team, r}, nil, temp_state)
        end)

      state = reply(:request_battle_status, nil, nil, state)

      # Queue status
      id_list = Coordinator.call_consul(lobby.id, :queue_state)

      state = reply(:battle, :queue_status, {lobby.id, id_list}, nil, state)

      %{state | lobby_id: lobby.id}
    else
      state
    end
  end

  @spec do_optimised_login_accepted(map(), map()) :: map()
  def do_optimised_login_accepted(state, user) do
    do_login_accepted(state, user)
    |> Map.put(:optimise_protocol, true)
  end

  @spec do_login_accepted(map(), map()) :: map()
  def do_login_accepted(state, user) do
    state = reply(:login_accepted, user.name, nil, state)
    state = reply(:motd, nil, nil, state)

    # Login the client
    _client = Client.login(user, :spring, state.ip)

    # Who is online?
    clients = Client.list_client_ids()
      |> Enum.map(fn userid ->
        Client.get_client_by_id(userid)
      end)
      |> Enum.filter(fn c -> c != nil end)

    # ADDUSER entries
    clients
    |> Enum.each(fn client ->
      send(self(), {:spring_add_user_from_login, client})
    end)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:post_login_delay])
    end

    # Battle entry commands
    # Once we know this is stable we can consider optimising it to not
    # need to send() to self a few dozen times
    Lobby.list_lobby_ids()
    |> Enum.each(fn lobby_id ->
      send(self(), {:global_battle_updated, lobby_id, :battle_opened})
      send(self(), {:global_battle_updated, lobby_id, :update_battle_info})

      battle = Lobby.get_lobby(lobby_id)
      if battle != nil and Map.has_key?(battle, :players) do
        battle.players
        |> Enum.each(fn player_id ->
          send(self(), {:add_user_to_battle, player_id, lobby_id, nil})
        end)
        # if not state.exempt_from_cmd_throttle do
        #   :timer.sleep(Application.get_env(:central, Teiserver)[:post_login_delay])
        # end
      end
    end)

    # CLIENTSTATUS entries
    clients
    |> Enum.each(fn client ->
      send(self(), {:updated_client, client, :client_updated_status})
    end)

    send(self(), {:action, {:login_end, nil}})

    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_user_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_battle_updates")
    :ok = PubSub.subscribe(Central.PubSub, "legacy_all_client_updates")
    :ok = PubSub.subscribe(Central.PubSub, "teiserver_client_messages:#{user.id}")

    PubSub.unsubscribe(Central.PubSub, "legacy_user_updates:#{user.id}")
    PubSub.subscribe(Central.PubSub, "legacy_user_updates:#{user.id}")

    PubSub.unsubscribe(Central.PubSub, "teiserver_global_lobby_updates")
    PubSub.subscribe(Central.PubSub, "teiserver_global_lobby_updates")

    Logger.metadata([request_id: "SpringTcpServer##{user.id}"])

    exempt_from_cmd_throttle = (user.moderator == true or User.is_bot?(user) == true)
    %{state |
      user: user,
      username: user.name,
      userid: user.id,
      exempt_from_cmd_throttle: exempt_from_cmd_throttle,
      optimise_protocol: false
    }
  end

  @spec do_join_room(map(), String.t()) :: map()
  def do_join_room(state, room_name) do
    room = Room.get_or_make_room(room_name, state.userid)
    Room.add_user_to_room(state.userid, room_name)

    PubSub.unsubscribe(Central.PubSub, "room:#{room_name}")
    :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")

    state = reply(:join_success, room_name, nil, state)
    state = reply(:add_user_to_room, {state.userid, room_name}, nil, state)

    author_name = User.get_username(room.author_id)
    state = reply(:channel_topic, {room_name, author_name}, nil, state)

    # Check for known users
    state = room.members
      |> Enum.reduce(state, fn (member_id, state_acc) ->
        # Does the user need to be added?
        new_state =
          case Map.has_key?(state_acc.known_users, member_id) do
            false ->
              client = Client.get_client_by_id(member_id)
              state_acc = reply(:user_logged_in, client, nil, state_acc)
              %{state_acc | known_users: Map.put(state_acc.known_users, member_id, Teiserver.SpringTcpServer._blank_user(member_id))}

            true ->
              state_acc
          end

        new_members =
          if Enum.member?(new_state.room_member_cache[room_name] || [], member_id) do
            new_state.room_member_cache[room_name] || []
          else
            [member_id | (new_state.room_member_cache[room_name] || [])]
          end

        new_cache = Map.put(state.room_member_cache, room_name, new_members)
        %{new_state | room_member_cache: new_cache}
      end)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    members =
      room.members
      |> Enum.map(fn member_id -> Client.get_client_by_id(member_id) end)
      |> Enum.filter(fn c -> c != nil end)
      |> Enum.map(fn client -> client.name end)
      |> List.insert_at(0, state.username)
      |> Enum.join(" ")

    reply(:channel_members, {members, room_name}, nil, state)
  end

  @spec prep_to_send(String.t() | list() | nil, String.t(), map) :: map()
  def prep_to_send(nil, _, state), do: state
  def prep_to_send("", _, state), do: state
  def prep_to_send([], _, state), do: state

  def prep_to_send(messages, msg_id, state) when is_list(messages) do
    prep_to_send(Enum.join(messages, ""), msg_id, state)
  end

  def prep_to_send(message, msg_id, state) do
    content =
      if msg_id != "" and msg_id != nil do
        message
        |> String.trim()
        |> String.split("\n")
        |> Enum.map_join("", fn m -> "#{msg_id} #{m}\n" end)
      else
        message
      end

    %{state | pending_messages: [content | state.pending_messages]}
  end

  @spec send_prepared_messages(map(), list) :: map()
  def send_prepared_messages(%{mock: true} = state, messages) do
    content = messages
      |> Enum.reverse()
      |> Enum.join("")

    send(state.test_pid, content)
    state
  end

  def send_prepared_messages(state, messages) do
    content = messages
      |> Enum.reverse()
      |> Enum.join("")

    state.transport.send(state.socket, content)
    state
  end

  # This sends a message to the self to send out a message
  @spec _send(String.t() | list() | nil, String.t(), map) :: map()
  # defp _send(msg, msg_id, state) do
  #   _send(msg, state.socket, state.transport, msg_id)
  # end

  defp _send("", _, state), do: state
  defp _send(nil, _, state), do: state

  defp _send(msg, msg_id, state) when is_list(msg) do
    _send(Enum.join(msg, ""), msg_id, state)
  end

  defp _send(msg, msg_id, state) do
    # If no line return at the end we should warn about that
    # I've made the mistake of forgetting it and wondering
    # why stuff wasn't working so it's staying here
    if not String.ends_with?(msg, "\n") do
      Logger.warn("Attempting to send message without newline at the end - #{msg}")
    end

    msg =
      if msg_id != "" and msg_id != nil do
        msg
        |> String.trim()
        |> String.split("\n")
        |> Enum.map_join("", fn m -> "#{msg_id} #{m}\n" end)
      else
        msg
      end

    _do_send(state, msg)
    %{state | server_messages: state.server_messages + 1}
  end

  # We have this so we can do tests without having to use sockets for everything
  # a mock socket has a custom function for sending of data
  defp _do_send(%{mock: true} = state, msg) do
    send(state.test_pid, msg)
  end

  defp _do_send(state, msg) do
    state.transport.send(state.socket, msg)
  end
end
