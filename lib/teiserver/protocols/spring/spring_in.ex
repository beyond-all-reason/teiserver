defmodule Teiserver.Protocols.SpringIn do
  @moduledoc """
  In component of the Spring protocol

  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Teiserver.Client
  alias Teiserver.Battle
  alias Teiserver.Room
  alias Teiserver.User
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]
  import Teiserver.Protocols.SpringOut, only: [reply: 4]
  alias Teiserver.Protocols.{Spring, SpringOut}
  alias Teiserver.Protocols.Spring.MatchmakingIn

  # The main entry point for the module and the wrapper around
  # parsing, processing and acting upon a player message
  @spec handle(String.t(), map) :: map
  def handle("", state), do: state
  def handle("\r\n", state), do: state

  def handle(data, state) do
    tuple =
      ~r/^(#[0-9]+ )?([a-z_A-Z0-9\.]+)(.*)?$/
      |> Regex.run(data)
      |> _clean()

    state =
      case tuple do
        {command, data, msg_id} ->
          do_handle(command, data, msg_id, state)

        nil ->
          Logger.debug("Bad match on command: '#{data}'")
          state
      end

    if state == nil do
      throw("nil state returned while handling: #{data}")
    end

    %{state | last_msg: System.system_time(:second)}
  end

  defp _clean(nil), do: nil

  defp _clean([_, msg_id, command, data]) do
    {command, String.trim(data), String.trim(msg_id)}
  end

  defp do_handle("c.matchmaking." <> cmd, data, msg_id, state) do
    MatchmakingIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("STARTTLS", _, msg_id, state) do
    do_handle("STLS", nil, msg_id, state)
  end

  defp do_handle("LISTCOMPFLAGS", _, msg_id, state) do
    reply(:compflags, nil, msg_id, state)
    state
  end

  # https://ninenines.eu/docs/en/ranch/1.7/guide/transports/ - Upgrading a TCP socket to SSL
  defp do_handle("STLS", _, msg_id, state) do
    reply(:okay, "STLS", msg_id, state)
    new_state = Teiserver.TcpServer.upgrade_connection(state)
    reply(:welcome, nil, msg_id, new_state)
  end

  defp do_handle("c.battles.list_ids", _, msg_id, state) do
    reply(:list_battles, Battle.list_battle_ids(), msg_id, state)
    state
  end

  # Specific handlers for different commands
  @spec do_handle(String.t(), String.t(), String.t(), map) :: map
  defp do_handle("MYSTATUS", data, msg_id, state) do
    case Regex.run(~r/([0-9]+)/, data) do
      [_, new_value] ->
        new_status =
          Spring.parse_client_status(new_value)
          |> Map.take([:in_game, :away])

        new_client =
          Client.get_client_by_id(state.userid)
          |> Map.merge(new_status)

        # This just accepts it and updates the client
        Client.update(new_client, :client_updated_status)

      nil ->
        _no_match(state, "MYSTATUS", msg_id, data)
    end

    state
  end

  defp do_handle("c.user.get_token_by_email", _data, msg_id, %{transport: :ranch_tcp} = state) do
    reply(
      :no,
      {"c.user.get_token_by_email", "cannot get token over insecure connection"},
      msg_id,
      state
    )
  end

  defp do_handle("c.user.get_token_by_email", data, msg_id, state) do
    case String.split(data, "\t") do
      [email, plain_text_password] ->
        user = Central.Account.get_user_by_email(email)

        response =
          if user do
            Central.Account.User.verify_password(plain_text_password, user.password)
          else
            false
          end

        if response do
          token = User.create_token(user)
          reply(:user_token, {email, token}, msg_id, state)
        else
          reply(:no, {"c.user.get_token_by_email", "invalid credentials"}, msg_id, state)
        end

      _ ->
        reply(:no, {"c.user.get_token_by_email", "bad format"}, msg_id, state)
    end
  end

  defp do_handle("c.user.get_token_by_name", _data, msg_id, %{transport: :ranch_tcp} = state) do
    reply(
      :no,
      {"c.user.get_token_by_name", "cannot get token over insecure connection"},
      msg_id,
      state
    )
  end

  defp do_handle("c.user.get_token_by_name", data, msg_id, state) do
    case String.split(data, "\t") do
      [name, plain_text_password] ->
        user = Central.Account.get_user_by_name(name)

        response =
          if user do
            Central.Account.User.verify_password(plain_text_password, user.password)
          else
            false
          end

        if response do
          token = User.create_token(user)
          reply(:user_token, {name, token}, msg_id, state)
        else
          reply(:no, {"c.user.get_token_by_name", "invalid credentials"}, msg_id, state)
        end

      _ ->
        reply(:no, {"c.user.get_token_by_name", "bad format"}, msg_id, state)
    end
  end

  defp do_handle("c.user.login", data, msg_id, state) do
    # Flags are optional hence the weird case statement
    [token, lobby, _flags] =
      case String.split(data, "\t") do
        [token, lobby, flags] -> [token, lobby, String.split(flags, " ")]
        [token, lobby] -> [token, lobby, []]
      end

    # Now try to login using a token
    response = User.try_login(token, state, state.ip, lobby)

    case response do
      {:error, "Unverified", userid} ->
        reply(:agreement, nil, msg_id, state)
        Map.put(state, :unverified_id, userid)

      {:ok, user} ->
        SpringOut.do_login_accepted(state, user)

      {:error, reason} ->
        Logger.debug("[command:login] denied with reason #{reason}")
        reply(:denied, reason, msg_id, state)
        state
    end

    state
  end

  defp do_handle("LOGIN", data, msg_id, state) do
    regex_result =
      case Regex.run(~r/^(\S+) (\S+) (0) ([0-9\.\*]+) ([^\t]+)?\t?([^\t]+)?\t?([^\t]+)?/, data) do
        nil -> nil
        result -> result ++ ["", "", "", "", ""]
      end

    response =
      case regex_result do
        [_, username, password, _cpu, _ip, lobby, _userid, _modes | _] ->
          username = User.clean_name(username)
          User.try_md5_login(username, password, state, state.ip, lobby)

        nil ->
          _no_match(state, "LOGIN", msg_id, data)
          {:error, "Invalid details format"}
      end

    case response do
      {:error, "Unverified", userid} ->
        reply(:agreement, nil, msg_id, state)
        Map.put(state, :unverified_id, userid)

      {:ok, user} ->
        SpringOut.do_login_accepted(state, user)

      {:error, reason} ->
        Logger.debug("[command:login] denied with reason #{reason}")
        reply(:denied, reason, msg_id, state)
        state
    end
  end

  defp do_handle("REGISTER", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, username, password_hash, email] ->
        case User.get_user_by_name(username) do
          nil ->
            User.register_user(username, email, password_hash, state.ip)
            reply(:registration_accepted, nil, msg_id, state)

          _ ->
            reply(:registration_denied, "User already exists", msg_id, state)
        end

      _ ->
        _no_match(state, "REGISTER", msg_id, data)
    end

    state
  end

  defp do_handle("CONFIRMAGREEMENT", code, msg_id, %{unverified_id: userid} = state) do
    case User.get_user_by_id(userid) do
      nil ->
        Logger.error("CONFIRMAGREEMENT - No user found for ID of '#{userid}'")
        state

      user ->
        case code == "#{user.verification_code}" do
          true ->
            User.verify_user(user)
            state

          false ->
            reply(:denied, "Incorrect code", msg_id, state)
            state
        end
    end
  end

  defp do_handle("CONFIRMAGREEMENT", _code, msg_id, state),
    do:
      reply(:servermsg, "You need to login before you can confirm the agreement.", msg_id, state)

  defp do_handle("CREATEBOTACCOUNT", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, botname, _owner_name] ->
        resp = User.register_bot(botname, state.userid)

        case resp do
          {:error, _reason} ->
            deny(state, msg_id)

          _ ->
            reply(
              :servermsg,
              "A new bot account #{botname} has been created, with the same password as #{
                state.username
              }",
              msg_id,
              state
            )
        end

      _ ->
        _no_match(state, "CREATEBOTACCOUNT", msg_id, data)
    end

    state
  end

  defp do_handle("RENAMEACCOUNT", new_name, msg_id, state) do
    User.rename_user(state.user, new_name)
    reply(:servermsg, "Username changed, please log back in", msg_id, state)
    send(self(), :terminate)
    state
  end

  defp do_handle("RESETPASSWORDREQUEST", email, msg_id, state) do
    case state.user == nil or email == state.user.email do
      true ->
        user = User.get_user_by_email(email)

        case user do
          nil ->
            reply(:reset_password_request_denied, "user error", msg_id, state)

          _ ->
            User.request_password_reset(user)
            reply(:reset_password_request_accepted, nil, msg_id, state)
        end

      false ->
        # They have requested a password reset for a different user?
        reply(:reset_password_request_denied, "data error", msg_id, state)
    end

    state
  end

  defp do_handle("RESETPASSWORD", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, email, code] ->
        user = User.get_user_by_email(email)

        cond do
          user == nil ->
            reply(:reset_password_actual_denied, "no_user", msg_id, state)

          user.password_reset_code == nil ->
            reply(:reset_password_actual_denied, "no_code", msg_id, state)

          state.userid != nil and state.userid != user.id ->
            reply(:reset_password_actual_denied, "wrong_user", msg_id, state)

          true ->
            case User.spring_reset_password(user, code) do
              :ok ->
                reply(:reset_password_actual_accepted, nil, msg_id, state)

              :error ->
                reply(:reset_password_actual_denied, "wrong_code", msg_id, state)
            end
        end

      _ ->
        _no_match(state, "RESETPASSWORD", msg_id, data)
    end

    state
  end

  defp do_handle("CHANGEEMAILREQUEST", new_email, msg_id, state) do
    new_user = User.request_email_change(state.user, new_email)

    case new_user do
      nil ->
        reply(:change_email_request_denied, "no user", msg_id, state)
        state

      _ ->
        reply(:change_email_request_accepted, nil, msg_id, state)
        %{state | user: new_user}
    end
  end

  defp do_handle("CHANGEEMAIL", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, new_email, supplied_code] ->
        [correct_code, expected_email] = state.user.email_change_code

        cond do
          correct_code != supplied_code ->
            reply(:change_email_denied, "bad code", msg_id, state)
            state

          new_email != expected_email ->
            reply(:change_email_denied, "bad email", msg_id, state)
            state

          true ->
            new_user = User.change_email(state.user, new_email)
            reply(:change_email_accepted, nil, msg_id, state)
            %{state | user: new_user}
        end

      _ ->
        _no_match(state, "CHANGEEMAIL", msg_id, data)
    end
  end

  defp do_handle("EXIT", _reason, _msg_id, state) do
    Client.disconnect(state.userid)
    send(self(), :terminate)
    state
  end

  defp do_handle("GETUSERINFO", _, msg_id, state) do
    ingame_hours = round(state.user.ingame_minutes / 60)

    [
      "Registration date: #{date_to_str(state.user.inserted_at, :ymd_hms)}",
      "Email address: #{state.user.email}",
      "Ingame time: #{ingame_hours}"
    ]
    |> Enum.each(fn msg ->
      reply(:servermsg, msg, msg_id, state)
    end)

    state
  end

  defp do_handle("CHANGEPASSWORD", data, msg_id, state) do
    case Regex.run(~r/(\S+)\t(\S+)/, data) do
      [_, md5_old_password, md5_new_password] ->
        case User.test_password(
               md5_old_password,
               state.user.password_hash
             ) do
          false ->
            reply(:servermsg, "Current password entered incorrectly", msg_id, state)

          true ->
            encrypted_new_password = User.encrypt_password(md5_new_password)
            new_user = %{state.user | password_hash: encrypted_new_password}
            User.update_user(new_user, persist: true)

            reply(
              :servermsg,
              "Password changed, you will need to use it next time you login",
              msg_id,
              state
            )
        end

      _ ->
        _no_match(state, "CHANGEPASSWORD", msg_id, data)
    end

    state
  end

  # Friend list
  defp do_handle("FRIENDLIST", _, msg_id, state),
    do: reply(:friendlist, state.user, msg_id, state)

  defp do_handle("FRIENDREQUESTLIST", _, msg_id, state),
    do: reply(:friendlist_request, state.user, msg_id, state)

  defp do_handle("UNFRIEND", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    new_user = User.remove_friend(state.userid, User.get_userid(username))
    %{state | user: new_user}
  end

  defp do_handle("ACCEPTFRIENDREQUEST", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    new_user = User.accept_friend_request(User.get_userid(username), state.userid)
    %{state | user: new_user}
  end

  defp do_handle("DECLINEFRIENDREQUEST", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    new_user = User.decline_friend_request(User.get_userid(username), state.userid)
    %{state | user: new_user}
  end

  defp do_handle("FRIENDREQUEST", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    User.create_friend_request(state.userid, User.get_userid(username))
    state
  end

  defp do_handle("IGNORE", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    User.ignore_user(state.userid, User.get_userid(username))
    state
  end

  defp do_handle("UNIGNORE", data, _msg_id, state) do
    [_, username] = String.split(data, "=")
    User.unignore_user(state.userid, User.get_userid(username))
    state
  end

  defp do_handle("IGNORELIST", _, msg_id, state),
    do: reply(:ignorelist, state.user, msg_id, state)

  # Chat related
  defp do_handle("JOIN", data, msg_id, state) do
    case Regex.run(~r/(\w+)(?:\t)?(\w+)?/, data) do
      [_, room_name] ->
        room = Room.get_or_make_room(room_name, state.userid)
        Room.add_user_to_room(state.userid, room_name)
        reply(:join_success, room_name, msg_id, state)
        reply(:joined_room, {state.username, room_name}, msg_id, state)

        author_name = User.get_username(room.author_id)
        reply(:channel_topic, {room_name, author_name}, msg_id, state)

        members =
          room.members
          |> Enum.map(fn m -> User.get_username(m) end)
          |> List.insert_at(0, state.username)
          |> Enum.join(" ")

        reply(:channel_members, {members, room_name}, msg_id, state)

        :ok = PubSub.subscribe(Central.PubSub, "room:#{room_name}")

      [_, room_name, _key] ->
        reply(:join_failure, {room_name, "Locked"}, msg_id, state)

      _ ->
        _no_match(state, "JOIN", msg_id, data)
    end

    state
  end

  defp do_handle("LEAVE", room_name, msg_id, state) do
    PubSub.unsubscribe(Central.PubSub, "room:#{room_name}")
    reply(:left_room, {state.username, room_name}, msg_id, state)
    Room.remove_user_from_room(state.userid, room_name)
    state
  end

  defp do_handle("CHANNELS", _, msg_id, state) do
    reply(:list_channels, nil, msg_id, state)
  end

  defp do_handle("SAY", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/, data) do
      [_, room_name, msg] ->
        Room.send_message(state.userid, room_name, msg)

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end

    state
  end

  defp do_handle("SAYEX", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/, data) do
      [_, room_name, msg] ->
        Room.send_message_ex(state.userid, room_name, msg)

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end

    state
  end

  defp do_handle("SAYPRIVATE", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/, data) do
      [_, to_name, msg] ->
        to_id = User.get_userid(to_name)
        User.send_direct_message(state.userid, to_id, msg)
        reply(:sent_direct_message, {to_id, msg}, msg_id, state)

      _ ->
        _no_match(state, "SAYPRIVATE", msg_id, data)
    end

    state
  end

  # Battles
  # OPENBATTLE type natType password port maxPlayers gameHash rank mapHash {engineName} {engineVersion} {map} {title} {gameName}
  defp do_handle("OPENBATTLE", data, msg_id, state) do
    response =
      case Regex.run(
             ~r/^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) ([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$/,
             data
           ) do
        [
          _,
          type,
          nattype,
          _password,
          port,
          max_players,
          game_hash,
          _rank,
          map_hash,
          engine_name,
          engine_version,
          map_name,
          name,
          game_name
        ] ->
          nattype =
            case nattype do
              "0" -> :none
              "1" -> :holepunch
              "2" -> :fixed
            end

          client = Client.get_client_by_id(state.userid)

          battle =
            %{
              founder_id: state.userid,
              founder_name: state.username,
              name: name,
              type: if(type == "0", do: :normal, else: :replay),
              nattype: nattype,
              port: port,
              max_players: int_parse(max_players),
              game_hash: game_hash,
              map_hash: map_hash,
              password: nil,
              rank: 0,
              locked: false,
              engine_name: engine_name,
              engine_version: engine_version,
              map_name: map_name,
              game_name: game_name,
              ip: client.ip
            }
            |> Battle.create_battle()
            |> Battle.add_battle()

          {:success, battle}

        nil ->
          _no_match(state, "OPENBATTLE", msg_id, data)
          {:failure, "No match"}
      end

    case response do
      {:success, battle} ->
        reply(:battle_opened, battle.id, msg_id, state)
        reply(:open_battle_success, battle.id, msg_id, state)
        PubSub.subscribe(Central.PubSub, "battle_updates:#{battle.id}")

        reply(:join_battle_success, battle, msg_id, state)

        # Send information about the battle to them
        reply(:add_script_tags, battle.tags, msg_id, state)

        battle.start_rectangles
        |> Enum.each(fn {team, r} ->
          reply(:add_start_rectangle, {team, r}, msg_id, state)
        end)

        # They are offered the chance to give a battle status
        reply(:request_battle_status, nil, msg_id, state)

        # Update the client
        Client.join_battle(state.userid, battle.id)

        # Update local state to point to this battle and say
        # we are the host
        %{state | battle_id: battle.id, battle_host: true}

      {:failure, reason} ->
        reply(:open_battle_failure, reason, msg_id, state)
        state
    end
  end

  defp do_handle("JOINBATTLE", data, msg_id, state) do
    response =
      case Regex.run(~r/^(\S+) (\S+) (\S+)$/, data) do
        [_, battle_id, _password, _script_password] ->
          Battle.can_join?(state.user, battle_id)

        nil ->
          {:failure, "No match"}
      end

    case response do
      {:success, battle} ->
        SpringOut.do_join_battle(state, battle)

      {:failure, "No match"} ->
        _no_match(state, "JOINBATTLE", msg_id, data)

      {:failure, reason} ->
        reply(:join_battle_failure, reason, msg_id, state)
        state
    end
  end

  defp do_handle("HANDICAP", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\d+)/, data) do
      [_, username, value] ->
        client_id = User.get_userid(username)
        value = int_parse(value)
        Battle.force_change_client(state.userid, client_id, :handicap, value)

      _ ->
        _no_match(state, "HANDICAP", msg_id, data)
    end

    state
  end

  defp do_handle("ADDSTARTRECT", data, msg_id, state) do
    case Regex.run(~r/(\d+) (\d+) (\d+) (\d+) (\d+)/, data) do
      [_, team, left, top, right, bottom] ->
        if Battle.allow?(state.userid, :addstartrect, state.battle_id) do
          Battle.add_start_rectangle(state.battle_id, [team, left, top, right, bottom])
        end

      _ ->
        _no_match(state, "ADDSTARTRECT", msg_id, data)
    end

    state
  end

  defp do_handle("REMOVESTARTRECT", team, _msg_id, state) do
    if Battle.allow?(state.userid, :removestartrect, state.battle_id) do
      Battle.remove_start_rectangle(state.battle_id, team)
    end

    state
  end

  defp do_handle("SETSCRIPTTAGS", data, _msg_id, state) do
    if Battle.allow?(state.userid, :setscripttags, state.battle_id) do
      tags =
        data
        |> String.split("\t")
        |> Enum.filter(fn t ->
          flag = String.contains?(t, "=")
          if flag != true, do: Logger.error("error in SETSCRIPTTAGS, = not found in tag: #{data}")
          flag
        end)
        |> Map.new(fn t ->
          [k, v] = String.split(t, "=")
          {String.downcase(k), v}
        end)

      Battle.set_script_tags(state.battle_id, tags)
    end

    state
  end

  defp do_handle("REMOVESCRIPTTAGS", data, _msg_id, state) do
    if Battle.allow?(state.userid, :setscripttags, state.battle_id) do
      keys =
        data
        |> String.downcase()
        |> String.split("\t")

      Battle.remove_script_tags(state.battle_id, keys)
    end

    state
  end

  defp do_handle("KICKFROMBATTLE", username, _msg_id, state) do
    if Battle.allow?(state.userid, :kickfrombattle, state.battle_id) do
      userid = User.get_userid(username)
      Battle.kick_user_from_battle(userid, state.battle_id)
    end

    state
  end

  defp do_handle("FORCETEAMNO", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, team_number] ->
        client_id = User.get_userid(username)
        value = int_parse(team_number)
        Battle.force_change_client(state.userid, client_id, :team_number, value)

      _ ->
        _no_match(state, "FORCETEAMNO", msg_id, data)
    end

    state
  end

  defp do_handle("FORCEALLYNO", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, ally_team_number] ->
        client_id = User.get_userid(username)
        value = int_parse(ally_team_number)
        Battle.force_change_client(state.userid, client_id, :ally_team_number, value)

      _ ->
        _no_match(state, "FORCEALLYNO", msg_id, data)
    end

    state
  end

  defp do_handle("FORCETEAMCOLOR", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, team_colour] ->
        client_id = User.get_userid(username)
        value = int_parse(team_colour)
        Battle.force_change_client(state.userid, client_id, :team_colour, value)

      _ ->
        _no_match(state, "FORCETEAMCOLOR", msg_id, data)
    end

    state
  end

  defp do_handle("FORCESPECTATORMODE", username, _msg_id, state) do
    client_id = User.get_userid(username)
    Battle.force_change_client(state.userid, client_id, :player, false)

    state
  end

  defp do_handle("DISABLEUNITS", data, _msg_id, state) do
    if Battle.allow?(state.userid, :disableunits, state.battle_id) do
      units = String.split(data, " ")
      Battle.disable_units(state.battle_id, units)
    end

    state
  end

  defp do_handle("ENABLEUNITS", data, _msg_id, state) do
    if Battle.allow?(state.userid, :enableunits, state.battle_id) do
      units = String.split(data, " ")
      Battle.enable_units(state.battle_id, units)
    end

    state
  end

  defp do_handle("ENABLEALLUNITS", _data, _msg_id, state) do
    if Battle.allow?(state.userid, :enableallunits, state.battle_id) do
      Battle.enable_all_units(state.battle_id)
    end

    state
  end

  defp do_handle("ADDBOT", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\d+) (\d+) (\S+)/, data) do
      [_, name, battlestatus, team_colour, ai_dll] ->
        if Battle.allow?(state.userid, :add_bot, state.battle_id) do
          bot_data =
            Battle.new_bot(
              Map.merge(
                %{
                  name: name,
                  owner_name: state.username,
                  owner_id: state.userid,
                  team_colour: team_colour,
                  ai_dll: ai_dll
                },
                Spring.parse_battle_status(battlestatus)
              )
            )

          Battle.add_bot_to_battle(
            state.battle_id,
            bot_data
          )
        end

      _ ->
        _no_match(state, "ADDBOT", msg_id, data)
    end

    state
  end

  defp do_handle("UPDATEBOT", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, name, battlestatus, team_colour] ->
        if Battle.allow?(state.userid, :update_bot, state.battle_id) do
          new_bot =
            Map.merge(
              %{
                team_colour: team_colour
              },
              Spring.parse_battle_status(battlestatus)
            )

          Battle.update_bot(state.battle_id, name, new_bot)
        end

      _ ->
        _no_match(state, "UPDATEBOT", msg_id, data)
    end

    state
  end

  defp do_handle("REMOVEBOT", botname, _msg_id, state) do
    if Battle.allow?(state.userid, :remove_bot, state.battle_id) do
      Battle.remove_bot(state.battle_id, botname)
    end

    state
  end

  defp do_handle("SAYBATTLE", msg, _msg_id, state) do
    if Battle.allow?(state.userid, :saybattle, state.battle_id) do
      Battle.say(state.userid, msg, state.battle_id)
    end

    state
  end

  defp do_handle("SAYBATTLEEX", msg, _msg_id, state) do
    if Battle.allow?(state.userid, :saybattleex, state.battle_id) do
      Battle.sayex(state.userid, msg, state.battle_id)
    end

    state
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#UPDATEBATTLEINFO:client
  defp do_handle("UPDATEBATTLEINFO", data, msg_id, state) do
    case Regex.run(~r/(\d+) (\d+) (\S+) (.+)$/, data) do
      [_, spectator_count, locked, map_hash, map_name] ->
        if Battle.allow?(state.userid, :updatebattleinfo, state.battle_id) do
          battle = Battle.get_battle(state.battle_id)

          new_battle = %{
            battle
            | spectator_count: int_parse(spectator_count),
              locked: locked == "1",
              map_hash: map_hash,
              map_name: map_name
          }

          Battle.update_battle(
            new_battle,
            {spectator_count, locked, map_hash, map_name},
            :update_battle_info
          )
        end

      _ ->
        _no_match(state, "UPDATEBATTLEINFO", msg_id, data)
    end

    state
  end

  defp do_handle("LEAVEBATTLE", _, _msg_id, %{battle_id: nil} = state) do
    Battle.remove_user_from_any_battle(state.userid)
    |> Enum.each(fn b ->
      PubSub.unsubscribe(Central.PubSub, "battle_updates:#{b}")
    end)

    %{state | battle_host: false}
  end

  defp do_handle("LEAVEBATTLE", _, _msg_id, state) do
    PubSub.unsubscribe(Central.PubSub, "battle_updates:#{state.battle_id}")
    Battle.remove_user_from_battle(state.userid, state.battle_id)
    %{state | battle_host: false}
  end

  defp do_handle("MYBATTLESTATUS", _, _, %{battle_id: nil} = state), do: state

  defp do_handle("MYBATTLESTATUS", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/, data) do
      [_, battlestatus, team_colour] ->
        updates =
          Spring.parse_battle_status(battlestatus)
          |> Map.take([:ready, :team_number, :ally_team_number, :player, :sync, :side])

        new_client =
          Client.get_client_by_id(state.userid)
          |> Map.merge(updates)
          |> Map.put(:team_colour, team_colour)

        # This one needs a bit more nuance, for now we'll wrap it in this
        # later it's possible we don't want players updating their status
        if Battle.allow?(state.userid, :mybattlestatus, state.battle_id) do
          Client.update(new_client, :client_updated_battlestatus)
        end

      _ ->
        _no_match(state, "MYBATTLESTATUS", msg_id, data)
    end

    state
  end

  # JSON/Gzip test
  defp do_handle("JSON", data, msg_id, state) do
    case data do
      "gzip" -> reply(:gzip, nil, msg_id, state)
      "gzip64" -> reply(:gzip64, nil, msg_id, state)
      "just64" -> reply(:just64, nil, msg_id, state)
    end

    state
  end

  # MISC
  defp do_handle("PING", _, msg_id, state) do
    reply(:pong, nil, msg_id, state)
    state
  end

  defp do_handle("RING", username, _msg_id, state) do
    userid = User.get_userid(username)
    User.ring(userid, state.userid)
    state
  end

  # Not handled catcher
  defp do_handle(cmd, data, msg_id, state) do
    _no_match(state, cmd, msg_id, data)
  end

  @spec _no_match(Map.t(), String.t(), String.t() | nil, Map.t()) :: Map.t()
  def _no_match(state, cmd, msg_id, data) do
    data =
      data
      |> String.replace("\t", "\\t")

    msg = "No incomming match for #{cmd} with data '#{data}'"
    Logger.error(msg)
    reply(:servermsg, msg, msg_id, state)
    state
  end

  @spec deny(map(), String.t()) :: map()
  defp deny(state, msg_id) do
    reply(:servermsg, "You do not have permission to execute that command", msg_id, state)
    state
  end
end
