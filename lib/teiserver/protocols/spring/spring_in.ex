defmodule Teiserver.Protocols.SpringIn do
  @moduledoc """
  In component of the Spring protocol

  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Teiserver.Battle.Lobby
  alias Teiserver.{Account, Coordinator, Battle, Room, User, Client}
  alias Phoenix.PubSub
  import Central.Helpers.NumberHelper, only: [int_parse: 1]
  import Central.Helpers.TimexHelper, only: [date_to_str: 2]
  import Teiserver.Protocols.SpringOut, only: [reply: 4]
  alias Teiserver.Protocols.{Spring, SpringOut}
  alias Teiserver.Protocols.Spring.{TelemetryIn, BattleIn, LobbyPolicyIn}

  @unoptimised_lobbies ["SLTS Client d", "LuaLobby Chobby"]

  @status_3_window 1_000
  @status_10_window 60_000

  @spec data_in(String.t(), Map.t()) :: Map.t()
  def data_in(data, state) do
    if Application.get_env(:central, Teiserver)[:extra_logging] == true or
         state.print_client_messages do
      if String.contains?(data, "c.user.get_token") or String.contains?(data, "LOGIN") do
        Logger.info("<-- #{state.username}: LOGIN/c.user.get_token")
      else
        Logger.info("<-- #{state.username}: #{Spring.format_log(data)}")
      end
    end

    new_state =
      if String.ends_with?(data, "\n") do
        data = state.message_part <> data

        data
        |> String.split("\n")
        |> Enum.reduce(state, fn data, acc ->
          handle(data, acc)
        end)
        |> Map.put(:message_part, "")
      else
        %{state | message_part: state.message_part <> data}
      end

    new_state
  end

  # The main entry point for the module and the wrapper around
  # parsing, processing and acting upon a player message
  @spec handle(String.t(), map) :: map
  def handle("", state), do: state
  def handle("\r\n", state), do: state

  def handle(data, state) do
    tuple =
      ~r/^(#[0-9]+ )?([a-z_A-Z0-9\.]+)(.*)?$/u
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

  # Spring matchmaking disabled
  defp do_handle("c.matchmaking." <> _cmd, _data, _msg_id, state) do
    state
  end

  defp do_handle("c.telemetry." <> cmd, data, msg_id, state) do
    TelemetryIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("c.battle." <> cmd, data, msg_id, state) do
    BattleIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("c.lobby_policy." <> cmd, data, msg_id, state) do
    LobbyPolicyIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("STARTTLS", _, msg_id, state) do
    do_handle("STLS", nil, msg_id, state)
  end

  defp do_handle("LISTCOMPFLAGS", _, msg_id, state) do
    reply(:compflags, nil, msg_id, state)
  end

  # https://ninenines.eu/docs/en/ranch/1.7/guide/transports/ - Upgrading a TCP socket to SSL
  defp do_handle("STLS", _, msg_id, state) do
    SpringOut.send_now("OK cmd=STLS\n", msg_id, state)
    state = Teiserver.SpringTcpServer.upgrade_connection(state)
    reply(:welcome, nil, msg_id, state)
  end

  defp do_handle("c.battles.list_ids", _, msg_id, state) do
    reply(:list_battles, Lobby.list_lobby_ids(), msg_id, state)
  end

  # Specific handlers for different commands
  @spec do_handle(String.t(), String.t(), String.t(), map) :: map
  defp do_handle("MYSTATUS", _data, msg_id, %{userid: nil} = state) do
    reply(:servermsg, "You need to login before you can set your status", msg_id, state)
  end

  defp do_handle("MYSTATUS", data, msg_id, state) do
    {_, state} = status_flood_protect?(state)

    # case status_flood_protect?(state) do
    #   {true, state} ->
    #     engage_flood_protection(state)
    #   {false, state} ->
    case Regex.run(~r/(\d+)/, data) do
      [_, new_value] ->
        new_status =
          Spring.parse_client_status(new_value)
          |> Map.take([:in_game, :away])

        case Client.get_client_by_id(state.userid) do
          nil ->
            :ok

          client ->
            # This just accepts it and updates the client
            new_client = Map.merge(client, new_status)

            if client.in_game != new_client.in_game or client.away != new_client.away do
              Client.update(new_client, :client_updated_status)
            end
        end

        case Client.get_client_by_id(state.userid) do
          nil ->
            :ok

          client ->
            # This just accepts it and updates the client
            new_client = Map.merge(client, new_status)

            if client.in_game != new_client.in_game or client.away != new_client.away do
              Client.update(new_client, :client_updated_status)
            end
        end

        state

      nil ->
        _no_match(state, "MYSTATUS", msg_id, data)
    end
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
    [token, lobby, lobby_hash, _flags] =
      case String.split(data, "\t") do
        [token, lobby, lobby_hash, flags] -> [token, lobby, lobby_hash, String.split(flags, " ")]
        [token, lobby | _] -> [token, lobby, "", ""]
      end

    # Now try to login using a token
    response = User.try_login(token, state.ip, lobby, lobby_hash)

    case response do
      {:error, "Unverified", userid} ->
        state = reply(:agreement, nil, msg_id, state)
        Map.put(state, :unverified_id, userid)

      {:ok, user} ->
        new_state =
          if Enum.member?(@unoptimised_lobbies, user.lobby_client) do
            SpringOut.do_login_accepted(state, user)
          else
            SpringOut.do_optimised_login_accepted(state, user)
          end

        # Do we have a clan?
        if user.clan_id do
          :timer.sleep(200)
          clan = Teiserver.Clans.get_clan!(user.clan_id)
          room_name = Room.clan_room_name(clan.tag)
          SpringOut.do_join_room(new_state, room_name)
        else
          new_state
        end

      {:error, "Banned" <> _} ->
        reply(
          :denied,
          "Banned, please see the discord channel #moderation-bot for more details",
          msg_id,
          state
        )

      {:error, reason} ->
        Logger.debug("[command:login] denied with reason #{reason}")
        reply(:denied, reason, msg_id, state)
    end
  end

  defp do_handle("LOGIN", data, msg_id, state) do
    regex_result =
      case Regex.run(~r/^(\S+) (\S+) (0) ([0-9\.\*]+) ([^\t]+)?\t?([^\t]+)?\t?([^\t]+)?/, data) do
        nil -> nil
        result -> result ++ ["", "", "", "", ""]
      end

    response =
      case regex_result do
        [_, username, password, _cpu, _ip, lobby, lobby_hash, _modes | _] ->
          username = User.clean_name(username)
          User.try_md5_login(username, password, state.ip, lobby, lobby_hash)

        nil ->
          _no_match(state, "LOGIN", msg_id, data)
          {:error, "Invalid details format"}
      end

    case response do
      {:error, "Unverified", userid} ->
        state = reply(:agreement, nil, msg_id, state)
        Map.put(state, :unverified_id, userid)

      {:ok, user} ->
        new_state =
          if Enum.member?(@unoptimised_lobbies, user.lobby_client) do
            SpringOut.do_login_accepted(state, user)
          else
            SpringOut.do_optimised_login_accepted(state, user)
          end

        # Do we have a clan?
        if user.clan_id do
          :timer.sleep(200)
          clan = Teiserver.Clans.get_clan!(user.clan_id)
          room_name = Room.clan_room_name(clan.tag)
          SpringOut.do_join_room(new_state, room_name)
        else
          new_state
        end

      {:error, "Banned" <> _} ->
        reply(
          :denied,
          "Banned, please see the discord channel #moderation-bot for more details",
          msg_id,
          state
        )

      {:error, reason} ->
        reply(:denied, reason, msg_id, state)
    end
  end

  defp do_handle("REGISTER", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, username, password_hash, email] ->
        case User.register_user_with_md5(username, email, password_hash, state.ip) do
          :success ->
            reply(:registration_accepted, nil, msg_id, state)

          {:error, reason} ->
            reply(:registration_denied, reason, msg_id, state)
        end

      _ ->
        _no_match(state, "REGISTER", msg_id, data)
    end
  end

  defp do_handle("CONFIRMAGREEMENT", code, msg_id, %{unverified_id: userid} = state) do
    case User.get_user_by_id(userid) do
      nil ->
        Logger.error("CONFIRMAGREEMENT - No user found for ID of '#{userid}'")
        state

      user ->
        correct_code = Account.get_user_stat_data(user.id)["verification_code"]

        case code == to_string(correct_code) do
          true ->
            User.verify_user(user)

            if Enum.member?(@unoptimised_lobbies, user.lobby_client) do
              SpringOut.do_login_accepted(state, user)
            else
              SpringOut.do_optimised_login_accepted(state, user)
            end

          false ->
            reply(:denied, "Incorrect code", msg_id, state)
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
              "A new bot account #{botname} has been created, with the same password as #{state.username}",
              msg_id,
              state
            )
        end

      _ ->
        _no_match(state, "CREATEBOTACCOUNT", msg_id, data)
    end
  end

  defp do_handle("RENAMEACCOUNT", new_name, msg_id, state) do
    case User.rename_user(state.userid, new_name) do
      :success ->
        state

      {:error, reason} ->
        Coordinator.send_to_user(state.userid, reason)
        reply(:servermsg, reason, msg_id, state)
    end
  end

  defp do_handle("RESETPASSWORDREQUEST", _, msg_id, state) do
    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    url = "https://#{host}/password_reset"

    reply(:okay, url, msg_id, state)
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

          new_email != expected_email ->
            reply(:change_email_denied, "bad email", msg_id, state)

          true ->
            new_user = User.change_email(state.user, new_email)
            state = reply(:change_email_accepted, nil, msg_id, state)
            %{state | user: new_user}
        end

      _ ->
        _no_match(state, "CHANGEEMAIL", msg_id, data)
    end
  end

  defp do_handle("EXIT", _reason, _msg_id, state) do
    Client.disconnect(state.userid, "Spring EXIT command")
    send(self(), :terminate)
    state
  end

  defp do_handle("GETUSERINFO", _, msg_id, state) do
    ingame_hours = User.rank_time(state.userid)

    [
      "Registration date: #{date_to_str(state.user.inserted_at, format: :ymd_hms, tz: "UTC")}",
      "Email address: #{state.user.email}",
      "Ingame time: #{ingame_hours}"
    ]
    |> Enum.reduce(state, fn msg, temp_state ->
      reply(:servermsg, msg, msg_id, temp_state)
    end)
  end

  defp do_handle("CHANGEPASSWORD", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
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
  end

  # SLDB commands
  defp do_handle("GETIP", username, msg_id, state) do
    if User.allow?(state.userid, :bot) do
      case Client.get_client_by_name(username) do
        nil ->
          reply(:no, "GETIP", msg_id, state)

        client ->
          reply(:user_ip, {username, client.ip}, msg_id, state)
      end
    else
      state
    end
  end

  defp do_handle("GETUSERID", data, msg_id, state) do
    if User.allow?(state.userid, :bot) do
      target = User.get_user_by_name(data)
      hash = target.lobby_hash
      reply(:user_id, {data, hash, target.springid}, msg_id, state)
    else
      state
    end
  end

  # Friend list
  defp do_handle("FRIENDLIST", _, msg_id, state),
    do: reply(:friendlist, state.user, msg_id, state)

  defp do_handle("FRIENDREQUESTLIST", _, msg_id, state),
    do: reply(:friendlist_request, state.user, msg_id, state)

  defp do_handle("UNFRIEND", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        new_user = User.remove_friend(state.userid, User.get_userid(username))
        %{state | user: new_user}

      _ ->
        _no_match(state, "UNFRIEND", msg_id, data)
    end
  end

  defp do_handle("ACCEPTFRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        new_user = User.accept_friend_request(User.get_userid(username), state.userid)
        %{state | user: new_user}

      _ ->
        _no_match(state, "ACCEPTFRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("DECLINEFRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        new_user = User.decline_friend_request(User.get_userid(username), state.userid)
        %{state | user: new_user}

      _ ->
        _no_match(state, "DECLINEFRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("FRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        User.create_friend_request(state.userid, User.get_userid(username))
        state

      _ ->
        _no_match(state, "FRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("IGNORE", data, _msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        User.ignore_user(state.userid, User.get_userid(username))

      _ ->
        :ok
    end

    state
  end

  defp do_handle("UNIGNORE", data, _msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        User.unignore_user(state.userid, User.get_userid(username))

      _ ->
        :ok
    end

    state
  end

  defp do_handle("IGNORELIST", _, msg_id, state),
    do: reply(:ignorelist, state.user, msg_id, state)

  defp do_handle("c.moderation.report_user", data, msg_id, state) do
    case String.split(data, "\t") do
      [target_name, _location_type, _location_id, reason] ->
        user = User.get_user_by_id(state.userid)
        target_id = User.get_userid(target_name)

        cond do
          Enum.member?(user.friends, target_id) ->
            User.send_direct_message(
              Coordinator.get_coordinator_userid(),
              state.userid,
              "Your report has not been submitted, you can't report a friend."
            )

            reply(:no, {"c.moderation.report_user", "reporting friend"}, msg_id, state)

          User.is_restricted?(state.userid, ["Community", "Reporting"]) ->
            reply(:no, {"c.moderation.report_user", "permission denied"}, msg_id, state)

          true ->
            client = Client.get_client_by_id(state.userid)

            {:ok, code} =
              Account.create_code(%{
                value: ExULID.ULID.generate(),
                purpose: "one_time_login",
                expires: Timex.now() |> Timex.shift(minutes: 5),
                user_id: state.userid,
                metadata: %{
                  ip: client.ip,
                  redirect: "/moderation/report_form/#{target_id}",
                  reason: reason
                }
              })

            host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
            url = "https://#{host}/one_time_login/#{code.value}"

            Coordinator.send_to_user(state.userid, [
              "To complete your report, please use the form on this link: #{url}",
              "The link will expire in 5 minutes."
            ])

            reply(:okay, nil, msg_id, state)
        end

      _ ->
        reply(:no, {"c.moderation.report_user", "bad command format"}, msg_id, state)
    end
  end

  # Chat related
  defp do_handle("JOIN", data, msg_id, state) do
    regex_result =
      case Regex.run(~r/(\w+)(?:\t)?(\w+)?/u, data) do
        [_, room_name] ->
          {room_name, ""}

        [_, room_name, key] ->
          {room_name, key}

        _ ->
          :nomatch
      end

    state =
      case regex_result do
        :nomatch ->
          _no_match(state, "JOIN", msg_id, data)

        {room_name, _key} ->
          case Room.can_join_room?(state.userid, room_name) do
            true ->
              SpringOut.do_join_room(state, room_name)

            {false, reason} ->
              reply(:join_failure, {room_name, reason}, msg_id, state)
          end
      end

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    state
  end

  defp do_handle("LEAVE", room_name, msg_id, state) do
    PubSub.unsubscribe(Central.PubSub, "room:#{room_name}")
    state = reply(:left_room, {state.username, room_name}, msg_id, state)
    Room.remove_user_from_room(state.userid, room_name)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    state
  end

  defp do_handle("CHANNELS", _, msg_id, state) do
    reply(:list_channels, nil, msg_id, state)
  end

  defp do_handle("SAY", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/u, data) do
      [_, room_name, msg] ->
        Room.send_message(state.userid, room_name, msg)
        state

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end
  end

  defp do_handle("SAYEX", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/u, data) do
      [_, room_name, msg] ->
        Room.send_message_ex(state.userid, room_name, msg)
        state

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end
  end

  # This is meant get a chat history, we currently don't store a chat history
  defp do_handle("GETCHANNELMESSAGES", _data, _msg_id, state) do
    state
  end

  defp do_handle("SAYPRIVATE", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/u, data) do
      [_, to_name, msg] ->
        to_id = User.get_userid(to_name)
        User.send_direct_message(state.userid, to_id, msg)
        reply(:sent_direct_message, {to_id, msg}, msg_id, state)

      _ ->
        _no_match(state, "SAYPRIVATE", msg_id, data)
    end
  end

  # Battles
  # OPENBATTLE type natType password port maxPlayers gameHash rank mapHash {engineName} {engineVersion} {map} {title} {gameName}
  defp do_handle("OPENBATTLE", data, msg_id, state) do
    response =
      case Regex.run(
             ~r/^(\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) (\S+) ([^\t]+)\t([^\t]+)\t([^\t]+)\t([^\t]+)\t(.+)$/u,
             data
           ) do
        [
          _,
          type,
          nattype,
          password,
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
              "0" -> "none"
              "1" -> "holepunch"
              "2" -> "fixed"
            end

          client = Client.get_client_by_id(state.userid)
          password = if Enum.member?(["empty", "*"], password), do: nil, else: password

          lobby =
            %{
              founder_id: state.userid,
              founder_name: state.username,
              name: name,
              type: if(type == "0", do: "normal", else: "replay"),
              nattype: nattype,
              port: int_parse(port),
              max_players: int_parse(max_players),
              game_hash: game_hash,
              map_hash: map_hash,
              password: password,
              rank: 0,
              locked: false,
              engine_name: engine_name,
              engine_version: engine_version,
              map_name: map_name,
              game_name: game_name,
              ip: client.ip
            }
            |> Lobby.create_lobby()
            |> Lobby.add_lobby()

          {:success, lobby}

        nil ->
          _no_match(state, "OPENBATTLE", msg_id, data)
          {:failure, "No match"}
      end

    case response do
      {:success, battle} ->
        state = reply(:battle_opened, battle.id, msg_id, state)
        state = reply(:open_battle_success, battle.id, msg_id, state)
        PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{battle.id}")
        PubSub.subscribe(Central.PubSub, "teiserver_lobby_updates:#{battle.id}")

        PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{battle.id}")
        PubSub.subscribe(Central.PubSub, "teiserver_lobby_chat:#{battle.id}")

        state = reply(:join_battle_success, battle, msg_id, state)

        # Send information about the battle to them
        modoptions = Battle.get_modoptions(battle.id)
        state = reply(:add_script_tags, modoptions, msg_id, state)

        battle.start_areas
        |> Enum.each(fn {team, r} ->
          reply(:add_start_rectangle, {team, r}, msg_id, state)
        end)

        # They are offered the chance to give a battle status
        state = reply(:request_battle_status, nil, msg_id, state)

        # Update the client
        Client.join_battle(state.userid, battle.id, true)

        # Update local state to point to this battle and say
        # we are the host
        %{
          state
          | lobby_id: battle.id,
            lobby_host: true,
            known_battles: [battle.id | state.known_battles]
        }

      {:failure, reason} ->
        reply(:open_battle_failure, reason, msg_id, state)
    end
  end

  defp do_handle("JOINBATTLE", _data, msg_id, %{user: nil} = state) do
    reply(:join_battle_failure, "No user detected", msg_id, state)
  end

  defp do_handle("JOINBATTLE", data, msg_id, state) do
    # Double space is here as the hashcode isn't sent by Chobby
    # Skylobby sends an * for empty so need to handle that
    data =
      case Regex.run(~r/^(\S+) \*? (\S+)$/u, data) do
        [_, lobby_id, script_password] ->
          "#{lobby_id} empty #{script_password}"

        nil ->
          data
      end

    response =
      case Regex.run(~r/^(\S+) (\S+) (\S+)$/u, data) do
        [_, lobby_id, password, script_password] ->
          Lobby.can_join?(state.userid, lobby_id, password, script_password)

        nil ->
          {:failure, "No match"}
      end

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    case response do
      {:waiting_on_host, script_password} ->
        Lobby.remove_user_from_any_lobby(state.userid)
        |> Enum.each(fn b ->
          PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{b}")
          PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{b}")
        end)

        %{state | script_password: script_password}

      {:failure, "No match"} ->
        _no_match(state, "JOINBATTLE", msg_id, data)

      {:failure, reason} ->
        reply(:join_battle_failure, reason, msg_id, state)
    end
  end

  defp do_handle("JOINBATTLEACCEPT", username, _msg_id, state) do
    userid = User.get_userid(username)
    Lobby.accept_join_request(userid, state.lobby_id)
    state
  end

  defp do_handle("JOINBATTLEDENY", data, _msg_id, state) do
    {username, reason} =
      case String.split(data, " ", parts: 2) do
        [username, reason] -> {username, reason}
        [username] -> {username, "no reason given by lobby host user"}
      end

    userid = User.get_userid(username)
    Lobby.deny_join_request(userid, state.lobby_id, reason)
    state
  end

  defp do_handle("HANDICAP", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\d+)/, data) do
      [_, username, value] ->
        client_id = User.get_userid(username)
        value = int_parse(value)
        Lobby.force_change_client(state.userid, client_id, %{handicap: value})
        state

      _ ->
        _no_match(state, "HANDICAP", msg_id, data)
    end
  end

  defp do_handle("ADDSTARTRECT", data, msg_id, state) do
    case Regex.run(~r/(\d+) (\d+) (\d+) (\d+) (\d+)/, data) do
      [_, team, left, top, right, bottom] ->
        if Lobby.allow?(state.userid, :addstartrect, state.lobby_id) do
          Lobby.add_start_rectangle(state.lobby_id, [team, left, top, right, bottom])
        end

        state

      _ ->
        _no_match(state, "ADDSTARTRECT", msg_id, data)
    end
  end

  defp do_handle("REMOVESTARTRECT", team, _msg_id, state) do
    if Lobby.allow?(state.userid, :removestartrect, state.lobby_id) do
      Lobby.remove_start_rectangle(state.lobby_id, team)
    end

    state
  end

  defp do_handle("SETSCRIPTTAGS", data, _msg_id, state) do
    if Lobby.allow?(state.userid, :setscripttags, state.lobby_id) do
      options =
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

      Battle.set_modoptions(state.lobby_id, options)
    end

    state
  end

  defp do_handle("REMOVESCRIPTTAGS", data, _msg_id, state) do
    if Lobby.allow?(state.userid, :setscripttags, state.lobby_id) do
      keys =
        data
        |> String.downcase()
        |> String.split(" ")

      Battle.remove_modoptions(state.lobby_id, keys)
    end

    state
  end

  defp do_handle("KICKFROMBATTLE", username, _msg_id, state) do
    if Lobby.allow?(state.userid, :kickfrombattle, state.lobby_id) do
      userid = User.get_userid(username)
      Lobby.kick_user_from_battle(userid, state.lobby_id)
    end

    state
  end

  defp do_handle("FORCETEAMNO", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, player_number] ->
        if Lobby.allow?(state.userid, :player_number, state.lobby_id) do
          client_id = User.get_userid(username)
          value = int_parse(player_number)
          Lobby.force_change_client(state.userid, client_id, %{player_number: value})
        end

      _ ->
        _no_match(state, "FORCETEAMNO", msg_id, data)
    end

    state
  end

  defp do_handle("FORCEALLYNO", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, team_number] ->
        client_id = User.get_userid(username)
        value = int_parse(team_number)
        Lobby.force_change_client(state.userid, client_id, %{team_number: value})

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
        Lobby.force_change_client(state.userid, client_id, %{team_colour: value |> to_string})

      _ ->
        _no_match(state, "FORCETEAMCOLOR", msg_id, data)
    end

    state
  end

  defp do_handle("FORCESPECTATORMODE", username, _msg_id, state) do
    client_id = User.get_userid(username)
    Lobby.force_change_client(state.userid, client_id, %{player: false})

    state
  end

  defp do_handle("DISABLEUNITS", data, _msg_id, state) do
    if Lobby.allow?(state.userid, :disableunits, state.lobby_id) do
      units = String.split(data, " ")
      Battle.disable_units(state.lobby_id, units)
    end

    state
  end

  defp do_handle("ENABLEUNITS", data, _msg_id, state) do
    if Lobby.allow?(state.userid, :enableunits, state.lobby_id) do
      units = String.split(data, " ")
      Battle.enable_units(state.lobby_id, units)
    end

    state
  end

  defp do_handle("ENABLEALLUNITS", _data, _msg_id, state) do
    if Lobby.allow?(state.userid, :enableallunits, state.lobby_id) do
      Battle.enable_all_units(state.lobby_id)
    end

    state
  end

  defp do_handle("ADDBOT", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\d+) (\d+) (.+)/, data) do
      [_, name, battlestatus, team_colour, ai_dll] ->
        if Lobby.allow?(state.userid, :add_bot, state.lobby_id) do
          bot_data =
            Lobby.new_bot(
              Map.merge(
                %{
                  name: name,
                  owner_name: state.username,
                  owner_id: state.userid,
                  team_colour: team_colour |> to_string,
                  ai_dll: ai_dll
                },
                Spring.parse_battle_status(battlestatus)
              )
            )

          Battle.add_bot_to_lobby(state.lobby_id, bot_data)
        end

      _ ->
        _no_match(state, "ADDBOT", msg_id, data)
    end

    state
  end

  defp do_handle("UPDATEBOT", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, botname, battlestatus, team_colour] ->
        if Lobby.allow?(state.userid, {:update_bot, botname}, state.lobby_id) do
          new_bot =
            Map.merge(
              %{
                team_colour: team_colour |> to_string
              },
              Spring.parse_battle_status(battlestatus)
            )

          Battle.update_bot(state.lobby_id, botname, new_bot)
        end

      _ ->
        _no_match(state, "UPDATEBOT", msg_id, data)
    end

    state
  end

  defp do_handle("REMOVEBOT", botname, _msg_id, state) do
    if Lobby.allow?(state.userid, {:remove_bot, botname}, state.lobby_id) do
      Battle.remove_bot(state.lobby_id, botname)
    end

    state
  end

  defp do_handle("SAYBATTLE", "system:" <> msg, msg_id, state) do
    do_handle("SAYBATTLE", String.trim(msg), msg_id, state)
  end

  defp do_handle("SAYBATTLE", "web:" <> msg, msg_id, state) do
    do_handle("SAYBATTLE", String.trim(msg), msg_id, state)
  end

  defp do_handle("SAYBATTLE", "a:" <> msg, msg_id, state) do
    do_handle("SAYBATTLE", String.trim(msg), msg_id, state)
  end

  defp do_handle("SAYBATTLE", "s:" <> msg, msg_id, state) do
    do_handle("SAYBATTLE", String.trim(msg), msg_id, state)
  end

  defp do_handle("SAYBATTLE", msg, _msg_id, state) do
    if Lobby.allow?(state.userid, :saybattle, state.lobby_id) do
      Lobby.say(state.userid, msg, state.lobby_id)
    end

    state
  end

  defp do_handle("SAYBATTLEEX", msg, _msg_id, state) do
    if Lobby.allow?(state.userid, :saybattleex, state.lobby_id) do
      Lobby.sayex(state.userid, msg, state.lobby_id)
    end

    state
  end

  # SAYBATTLEPRIVATEEX username
  defp do_handle("SAYBATTLEPRIVATEEX", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/u, data) do
      [_, to_name, msg] ->
        to_id = User.get_userid(to_name)

        if Lobby.allow?(state.userid, :saybattleprivateex, state.lobby_id) do
          Lobby.sayprivateex(state.userid, to_id, msg, state.lobby_id)
        end

      _ ->
        _no_match(state, "SAYBATTLEPRIVATEEX", msg_id, data)
    end

    state
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#UPDATEBATTLEINFO:client
  defp do_handle("UPDATEBATTLEINFO", data, msg_id, state) do
    case Regex.run(~r/(\d+) (\d+) (\S+) (.+)$/, data) do
      [_, spectator_count, locked, map_hash, map_name] ->
        if Lobby.allow?(state.userid, :updatebattleinfo, state.lobby_id) do
          Battle.update_lobby_values(state.lobby_id, %{
            spectator_count: spectator_count,
            locked: locked == "1",
            map_hash: map_hash,
            map_name: map_name
          })
        end

      _ ->
        _no_match(state, "UPDATEBATTLEINFO", msg_id, data)
    end

    state
  end

  defp do_handle("LEAVEBATTLE", _, _msg_id, %{lobby_id: nil} = state) do
    Lobby.remove_user_from_any_lobby(state.userid)
    |> Enum.each(fn b ->
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{b}")
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{b}")
    end)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    %{state | lobby_host: false}
  end

  defp do_handle("LEAVEBATTLE", _, _msg_id, state) do
    # Remove them from all the battles anyways, just in case
    Lobby.remove_user_from_any_lobby(state.userid)
    |> Enum.each(fn b ->
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{b}")
      PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{b}")
    end)

    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_updates:#{state.lobby_id}")
    PubSub.unsubscribe(Central.PubSub, "teiserver_lobby_chat:#{state.lobby_id}")
    Lobby.remove_user_from_battle(state.userid, state.lobby_id)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:central, Teiserver)[:spring_post_state_change_delay])
    end

    %{state | lobby_host: false}
  end

  defp do_handle("MYBATTLESTATUS", _, _, %{lobby_id: nil} = state), do: state

  defp do_handle("MYBATTLESTATUS", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/, data) do
      [_, battlestatus, team_colour] ->
        updates =
          Spring.parse_battle_status(battlestatus)
          |> Map.take([:ready, :player_number, :team_number, :player, :sync, :side])

        existing = Client.get_client_by_id(state.userid)

        new_client =
          (existing || %{})
          |> Map.merge(updates)
          |> Map.put(:team_colour, team_colour |> to_string)

        # This one needs a bit more nuance, for now we'll wrap it in this
        # later it's possible we don't want players updating their status
        if Lobby.allow?(state.userid, :mybattlestatus, state.lobby_id) do
          case Coordinator.attempt_battlestatus_update(new_client, state.lobby_id) do
            {true, allowed_client} ->
              Client.update(allowed_client, :client_updated_battlestatus)

            {false, _} ->
              Client.update(existing, :client_updated_battlestatus)
          end
        end

      _ ->
        _no_match(state, "MYBATTLESTATUS", msg_id, data)
    end

    state
  end

  # MISC
  defp do_handle("PING", _, msg_id, state) do
    reply(:pong, nil, msg_id, state)
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

    msg =
      "No incomming match for #{cmd} with data '#{Kernel.inspect(data)}'. Userid #{state.userid}"

    Logger.info(msg)
    reply(:servermsg, msg, msg_id, state)
  end

  @spec deny(map(), String.t()) :: map()
  defp deny(state, msg_id) do
    reply(:servermsg, "You do not have permission to execute that command", msg_id, state)
  end

  @spec status_flood_protect?(map()) :: {boolean, map()}
  defp status_flood_protect?(%{exempt_from_cmd_throttle: true} = state), do: {false, state}

  defp status_flood_protect?(state) do
    now = System.system_time(:millisecond)
    limiter10 = now - @status_10_window
    limiter3 = now - @status_3_window

    status_timestamps =
      [now | state.status_timestamps]
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter10 end)

    recent_timestamps =
      status_timestamps
      |> Enum.filter(fn cmd_ts -> cmd_ts > limiter3 end)

    cond do
      Enum.count(status_timestamps) > 10 ->
        Logger.warn("status_flood_protection:10 - #{state.username}/#{state.userid}")
        {true, %{state | status_timestamps: status_timestamps}}

      Enum.count(recent_timestamps) > 3 ->
        Logger.warn("status_flood_protection:3 - #{state.username}/#{state.userid}")
        {true, %{state | status_timestamps: status_timestamps}}

      true ->
        {false, %{state | status_timestamps: status_timestamps}}
    end
  end

  # @spec engage_flood_protection(map()) :: {:stop, String.t(), map()}
  # defp engage_flood_protection(state) do
  #   state.protocol_out.reply(:disconnect, "Spring status flood protection", nil, state)
  #   User.set_flood_level(state.userid, 10)
  #   Client.disconnect(state.userid, "SpringIn.status.flood_protection")
  #   Logger.error("Spring Status command overflow from #{state.username}/#{state.userid}")
  #   {:stop, "Spring status flood protection", state}
  # end
end
