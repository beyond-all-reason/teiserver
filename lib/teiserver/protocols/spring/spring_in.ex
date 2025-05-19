defmodule Teiserver.Protocols.SpringIn do
  @moduledoc """
  In component of the Spring protocol

  Protocol definition:
  https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html
  """
  require Logger
  alias Teiserver.{Account, Lobby, Coordinator, Battle, Room, CacheUser, Client, Config}
  alias Phoenix.PubSub
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1]
  import Teiserver.Helper.TimexHelper, only: [date_to_str: 2]
  import Teiserver.Protocols.SpringOut, only: [reply: 4]
  alias Teiserver.Protocols.{Spring, SpringOut}

  alias Teiserver.Protocols.Spring.{
    AuthIn,
    TelemetryIn,
    BattleIn,
    LobbyPolicyIn,
    UserIn,
    SystemIn,
    PartyIn
  }

  @optimisation_level %{
    "LuaLobby Chobby" => :partial,
    "SLTS Client d" => :none
  }

  @status_3_window 1_000
  @status_10_window 60_000

  @action_commands ~w(SAY SAYEX SAYPRIVATE SAYBATTLE SAYBATTLEPRIVATEEX JOINBATTLE LEAVEBATTLE)

  @spec data_in(String.t(), map()) :: map()
  def data_in(data, state) do
    if Config.get_site_config_cache("debug.Print incoming messages") or
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
      if String.valid?(data) do
        parse_in_message(data)
      else
        Logger.error("Invalid characters in data: '#{data}'")

        nil
      end

    state =
      case tuple do
        {command, data, msg_id} ->
          state = do_handle(command, data, msg_id, state)

          if Enum.member?(@action_commands, command) do
            Map.put(state, :last_action_timestamp, System.system_time(:second))
          else
            state
          end

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

  defp do_handle("c.auth." <> cmd, data, msg_id, state) do
    AuthIn.do_handle(cmd, data, msg_id, state)
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

  defp do_handle("c.user." <> cmd, data, msg_id, state) do
    UserIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("c.system." <> cmd, data, msg_id, state) do
    SystemIn.do_handle(cmd, data, msg_id, state)
  end

  defp do_handle("c.party." <> cmd, data, msg_id, state) do
    PartyIn.do_handle(cmd, data, msg_id, state)
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
    new_state = Teiserver.SpringTcpServer.upgrade_connection(state)
    reply(:welcome, nil, msg_id, new_state)
  end

  defp do_handle("c.battles.list_ids", _, msg_id, state) do
    reply(:list_battles, Lobby.list_lobby_ids(), msg_id, state)
    state
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

      nil ->
        _no_match(state, "MYSTATUS", msg_id, data)
    end

    # end

    state
  end

  defp do_handle("LOGIN", data, msg_id, state) do
    # This is in place to make it easier to copy-paste commands
    data = String.replace(data, "    ", "\t")

    regex_result =
      case Regex.run(~r/^(\S+) (\S+) (0) ([0-9\.\*]+) ([^\t]+)?\t?([^\t]+)?\t?([^\t]+)?/, data) do
        nil -> nil
        result -> result ++ ["", "", "", "", ""]
      end

    response =
      case regex_result do
        [_, username, password, _cpu, _ip, lobby, lobby_hash, _modes | _] ->
          username = CacheUser.clean_name(username)
          CacheUser.try_md5_login(username, password, state.ip, lobby, lobby_hash)

        nil ->
          _no_match(state, "LOGIN", msg_id, data)
          {:error, "Invalid details format"}
      end

    case response do
      {:error, "Unverified", userid} ->
        reply(:agreement, nil, msg_id, state)
        Map.put(state, :unverified_id, userid)

      {:error, "Queued", userid, lobby, lobby_hash} ->
        reply(:login_queued, nil, msg_id, state)

        Map.merge(state, %{
          lobby: lobby,
          lobby_hash: lobby_hash,
          queued_userid: userid
        })

      {:ok, user} ->
        optimisation_level = Map.get(@optimisation_level, user.lobby_client, :full)

        new_state =
          SpringOut.do_login_accepted(state, user, optimisation_level)
          |> Map.put(:party_id, nil)

        # Do we have a clan?
        if user.clan_id do
          :timer.sleep(200)
          clan = Teiserver.Clans.get_clan!(user.clan_id)
          room_name = Room.clan_room_name(clan.tag)
          SpringOut.do_join_room(new_state, room_name)
        end

        new_state

      {:error, "Banned" <> _} ->
        reply(
          :denied,
          "Banned, please see the discord channel #moderation-bot for more details",
          msg_id,
          state
        )

        state

      {:error, reason} ->
        Logger.debug("[command:login] denied with reason #{reason}")
        reply(:denied, reason, msg_id, state)
        state
    end
  end

  defp do_handle("REGISTER", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+) (\S+)/, data) do
      [_, username, password_hash, email] ->
        case CacheUser.register_user_with_md5(username, email, password_hash, state.ip) do
          :success ->
            reply(:registration_accepted, nil, msg_id, state)

          {:error, reason} ->
            reply(:registration_denied, reason, msg_id, state)
        end

      _ ->
        _no_match(state, "REGISTER", msg_id, data)
    end

    state
  end

  defp do_handle("CONFIRMAGREEMENT", code, msg_id, %{unverified_id: userid} = state) do
    case CacheUser.get_user_by_id(userid) do
      nil ->
        Logger.error("CONFIRMAGREEMENT - No user found for ID of '#{userid}'")
        state

      user ->
        correct_code = Account.get_user_stat_data(user.id)["verification_code"]

        case code == to_string(correct_code) do
          true ->
            CacheUser.verify_user(user)

            optimisation_level = Map.get(@optimisation_level, user.lobby_client, :full)
            SpringOut.do_login_accepted(state, user, optimisation_level)

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
        resp = CacheUser.register_bot(botname, state.userid)

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

    state
  end

  defp do_handle("RENAMEACCOUNT", new_name, msg_id, state) do
    case CacheUser.rename_user(state.userid, new_name) do
      :success ->
        :ok

      {:error, reason} ->
        Coordinator.send_to_user(state.userid, reason)
        reply(:servermsg, reason, msg_id, state)
    end

    state
  end

  defp do_handle("RESETPASSWORDREQUEST", _, msg_id, state) do
    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/password_reset"

    reply(:okay, url, msg_id, state)
  end

  defp do_handle("CHANGEEMAILREQUEST", new_email, msg_id, state) do
    result = CacheUser.request_email_change(state.user, new_email)

    case result do
      {:error, reason} ->
        reply(:change_email_request_denied, reason, msg_id, state)
        state

      {:ok, new_user} ->
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
            new_user = CacheUser.change_email(state.user, new_email)
            reply(:change_email_accepted, nil, msg_id, state)
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
    ingame_hours = CacheUser.rank_time(state.userid)

    [
      "Registration date: #{date_to_str(state.user.inserted_at, format: :ymd_hms, tz: "UTC")}",
      "Email address: #{state.user.email}",
      "Ingame time: #{ingame_hours}"
    ]
    |> Enum.each(fn msg ->
      reply(:servermsg, msg, msg_id, state)
    end)

    state
  end

  defp do_handle("CHANGEPASSWORD", data, msg_id, state) do
    # Unused
    _no_match(state, "CHANGEPASSWORD", msg_id, data)

    state
  end

  # SLDB commands
  defp do_handle("GETIP", username, msg_id, state) do
    if CacheUser.allow?(state.userid, :bot) do
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
    if CacheUser.allow?(state.userid, :bot) do
      target = CacheUser.get_user_by_name(data)
      hash = target.lobby_hash
      reply(:user_id, {data, hash, target.id}, msg_id, state)
    else
      state
    end
  end

  # Friend list
  defp do_handle("FRIENDLIST", _, msg_id, state),
    do: reply(:friendlist, state.userid, msg_id, state)

  defp do_handle("FRIENDREQUESTLIST", _, msg_id, state),
    do: reply(:friendlist_request, state.userid, msg_id, state)

  defp do_handle("UNFRIEND", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        case Account.get_friend(state.userid, target_userid) do
          nil ->
            state

          friend_object ->
            Account.delete_friend(friend_object)
            state
        end

      _ ->
        _no_match(state, "UNFRIEND", msg_id, data)
    end
  end

  defp do_handle("ACCEPTFRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        if target_userid && state.userid do
          Account.accept_friend_request(target_userid, state.userid)
        end

        state

      _ ->
        _no_match(state, "ACCEPTFRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("DECLINEFRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        if target_userid && state.userid do
          Account.decline_friend_request(target_userid, state.userid)
        end

        state

      _ ->
        _no_match(state, "DECLINEFRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("FRIENDREQUEST", data, msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        if Account.can_send_friend_request?(state.userid, target_userid) do
          Account.create_friend_request(%{
            from_user_id: state.userid,
            to_user_id: target_userid
          })
        end

        state

      _ ->
        _no_match(state, "FRIENDREQUEST", msg_id, data)
    end
  end

  defp do_handle("IGNORE", data, _msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        if target_userid && state.userid do
          Account.ignore_user(state.userid, target_userid)
        end

      _ ->
        :ok
    end

    state
  end

  defp do_handle("UNIGNORE", data, _msg_id, state) do
    case String.split(data, "=") do
      [_, username] ->
        target_userid = Account.get_userid_from_name(username)

        if target_userid && state.userid do
          Account.unignore_user(state.userid, target_userid)
        end

      _ ->
        :ok
    end

    state
  end

  defp do_handle("IGNORELIST", _, msg_id, state),
    do: reply(:ignorelist, state.userid, msg_id, state)

  defp do_handle("c.moderation.report_user", data, msg_id, state) do
    case String.split(data, "\t") do
      [target_name, _location_type, _location_id, reason] ->
        friend_list = Account.list_friend_ids_of_user(state.userid)
        target_id = CacheUser.get_userid(target_name)

        cond do
          Enum.member?(friend_list, target_id) ->
            CacheUser.send_direct_message(
              Coordinator.get_coordinator_userid(),
              state.userid,
              "Your report has not been submitted, you can't report a friend."
            )

            reply(:no, {"c.moderation.report_user", "reporting friend"}, msg_id, state)

          CacheUser.is_restricted?(state.userid, ["Community", "Reporting"]) ->
            reply(:no, {"c.moderation.report_user", "permission denied"}, msg_id, state)

          true ->
            client = Client.get_client_by_id(state.userid)

            {:ok, code} =
              Account.create_code(%{
                value: ExULID.ULID.generate(),
                purpose: "one_time_login",
                expires: Timex.now() |> Timex.shift(minutes: 30),
                user_id: state.userid,
                metadata: %{
                  ip: client.ip,
                  redirect: "/moderation/report_user/#{target_id}",
                  reason: reason
                }
              })

            host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
            url = "https://#{host}/one_time_login/#{code.value}"

            Coordinator.send_to_user(state.userid, [
              "To complete your report, please use the form on this link: #{url}",
              "The link will expire in 30 minutes.",
              "If the link doesn't work, you can also view your matches at https://#{host}/battle and report players from the player tab of the relevant battle."
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
      :timer.sleep(Application.get_env(:teiserver, Teiserver)[:spring_post_state_change_delay])
    end

    state
  end

  defp do_handle("LEAVE", room_name, msg_id, state) do
    PubSub.unsubscribe(Teiserver.PubSub, "room:#{room_name}")
    reply(:left_room, {state.username, room_name}, msg_id, state)
    Room.remove_user_from_room(state.userid, room_name)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:teiserver, Teiserver)[:spring_post_state_change_delay])
    end

    state
  end

  defp do_handle("CHANNELS", _, msg_id, state) do
    reply(:list_channels, nil, msg_id, state)
  end

  defp do_handle("SAY", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/u, data) do
      [_, room_name, msg] ->
        msg =
          msg
          |> String.trim()
          |> String.slice(0..256)

        Room.send_message(state.userid, room_name, msg)

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end

    state
  end

  defp do_handle("SAYEX", data, msg_id, state) do
    case Regex.run(~r/(\w+) (.+)/u, data) do
      [_, room_name, msg] ->
        msg =
          msg
          |> String.trim()
          |> String.slice(0..256)

        Room.send_message_ex(state.userid, room_name, msg)

      _ ->
        _no_match(state, "SAY", msg_id, data)
    end

    state
  end

  # This is meant get a chat history, we currently don't store a chat history
  defp do_handle("GETCHANNELMESSAGES", _data, _msg_id, state) do
    state
  end

  defp do_handle("SAYPRIVATE", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/u, data) do
      [_, to_name, msg] ->
        to_id = CacheUser.get_userid(to_name)
        CacheUser.send_direct_message(state.userid, to_id, msg)
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

          cond do
            client == nil ->
              {:failure, "No client"}

            not CacheUser.is_bot?(state.userid) ->
              {:failure, "Not a bot"}

            true ->
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
          end

        nil ->
          _no_match(state, "OPENBATTLE", msg_id, data)
          {:failure, "No match"}
      end

    case response do
      {:success, battle} ->
        reply(:battle_opened, battle.id, msg_id, state)
        reply(:open_battle_success, battle.id, msg_id, state)
        PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{battle.id}")
        PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{battle.id}")

        PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{battle.id}")
        PubSub.subscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{battle.id}")

        reply(:join_battle_success, battle, msg_id, state)

        # Send information about the battle to them
        modoptions = Battle.get_modoptions(battle.id)
        reply(:add_script_tags, modoptions, msg_id, state)

        battle.start_areas
        |> Enum.each(fn {team, r} ->
          reply(:add_start_rectangle, {team, r}, msg_id, state)
        end)

        # They are offered the chance to give a battle status
        reply(:request_battle_status, nil, msg_id, state)

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
        state
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
      :timer.sleep(Application.get_env(:teiserver, Teiserver)[:spring_post_state_change_delay])
    end

    case response do
      {:waiting_on_host, script_password} ->
        Lobby.remove_user_from_any_lobby(state.userid)
        |> Enum.each(fn b ->
          PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{b}")
        end)

        %{state | script_password: script_password}

      {:failure, "No match"} ->
        _no_match(state, "JOINBATTLE", msg_id, data)

      {:failure, reason} ->
        reply(:join_battle_failure, reason, msg_id, state)
    end
  end

  defp do_handle("JOINBATTLEACCEPT", username, _msg_id, state) do
    userid = CacheUser.get_userid(username)
    Lobby.accept_join_request(userid, state.lobby_id)
    state
  end

  defp do_handle("JOINBATTLEDENY", data, _msg_id, state) do
    {username, reason} =
      case String.split(data, " ", parts: 2) do
        [username, reason] -> {username, reason}
        [username] -> {username, "no reason given by lobby host user"}
      end

    userid = CacheUser.get_userid(username)
    Lobby.deny_join_request(userid, state.lobby_id, reason)
    state
  end

  defp do_handle("HANDICAP", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\d+)/, data) do
      [_, username, value] ->
        client_id = CacheUser.get_userid(username)
        value = int_parse(value)
        Lobby.force_change_client(state.userid, client_id, %{handicap: value})

      _ ->
        _no_match(state, "HANDICAP", msg_id, data)
    end

    state
  end

  defp do_handle("ADDSTARTRECT", data, msg_id, state) do
    case Regex.run(~r/(\d+) (\d+) (\d+) (\d+) (\d+)/, data) do
      [_, team, left, top, right, bottom] ->
        if Lobby.allow?(state.userid, :addstartrect, state.lobby_id) do
          Lobby.add_start_rectangle(state.lobby_id, [team, left, top, right, bottom])
        end

      _ ->
        _no_match(state, "ADDSTARTRECT", msg_id, data)
    end

    state
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
      userid = CacheUser.get_userid(username)
      Lobby.kick_user_from_battle(userid, state.lobby_id)
    end

    state
  end

  defp do_handle("FORCETEAMNO", data, msg_id, state) do
    case Regex.run(~r/(\S+) (\S+)/, data) do
      [_, username, player_number] ->
        if Lobby.allow?(state.userid, :player_number, state.lobby_id) do
          client_id = CacheUser.get_userid(username)
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
        client_id = CacheUser.get_userid(username)
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
        client_id = CacheUser.get_userid(username)
        value = int_parse(team_colour)
        Lobby.force_change_client(state.userid, client_id, %{team_colour: value |> to_string})

      _ ->
        _no_match(state, "FORCETEAMCOLOR", msg_id, data)
    end

    state
  end

  defp do_handle("FORCESPECTATORMODE", username, _msg_id, state) do
    client_id = CacheUser.get_userid(username)
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
      lowercase_msg = String.downcase(msg)

      msg_sliced =
        cond do
          CacheUser.is_bot?(state.userid) ->
            msg

          String.starts_with?(lowercase_msg, "!bset tweakdefs") ||
              String.starts_with?(lowercase_msg, "!bset tweakunits") ->
            msg |> String.trim() |> String.slice(0..16384)

          String.starts_with?(lowercase_msg, ["$welcome-message", "!welcome-message"]) ->
            msg |> String.trim() |> String.slice(0..1024)

          true ->
            msg |> String.trim() |> String.slice(0..256)
        end

      Lobby.say(state.userid, msg_sliced, state.lobby_id)
    end

    state
  end

  defp do_handle("SAYBATTLEEX", msg, _msg_id, state) do
    if Lobby.allow?(state.userid, :saybattleex, state.lobby_id) do
      lowercase_msg = String.downcase(msg)

      msg_sliced =
        cond do
          CacheUser.is_bot?(state.userid) ->
            msg

          String.starts_with?(lowercase_msg, "!bset tweakdefs") ||
              String.starts_with?(lowercase_msg, "!bset tweakunits") ->
            msg |> String.trim() |> String.slice(0..16384)

          String.starts_with?(lowercase_msg, ["$welcome-message", "!welcome-message"]) ->
            msg |> String.trim() |> String.slice(0..1024)

          true ->
            msg |> String.trim() |> String.slice(0..256)
        end

      Lobby.sayex(state.userid, msg_sliced, state.lobby_id)
    end

    state
  end

  # SAYBATTLEPRIVATEEX username
  defp do_handle("SAYBATTLEPRIVATEEX", data, msg_id, state) do
    case Regex.run(~r/(\S+) (.+)/u, data) do
      [_, to_name, msg] ->
        to_id = CacheUser.get_userid(to_name)

        if Lobby.allow?(state.userid, :saybattleprivateex, state.lobby_id) do
          msg_sliced =
            if CacheUser.is_bot?(state.userid) do
              msg
            else
              msg
              |> String.trim()
              |> String.slice(0..256)
            end

          Lobby.sayprivateex(state.userid, to_id, msg_sliced, state.lobby_id)
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
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{b}")
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{b}")
    end)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:teiserver, Teiserver)[:spring_post_state_change_delay])
    end

    %{state | lobby_host: false}
  end

  defp do_handle("LEAVEBATTLE", _, _msg_id, state) do
    # Remove them from all the battles anyways, just in case
    Lobby.remove_user_from_any_lobby(state.userid)
    |> Enum.each(fn b ->
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{b}")
      PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{b}")
    end)

    PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_updates:#{state.lobby_id}")
    PubSub.unsubscribe(Teiserver.PubSub, "teiserver_lobby_chat:#{state.lobby_id}")
    Lobby.remove_user_from_battle(state.userid, state.lobby_id)

    if not state.exempt_from_cmd_throttle do
      :timer.sleep(Application.get_env(:teiserver, Teiserver)[:spring_post_state_change_delay])
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

            nil ->
              :ok
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
    state
  end

  # https://springrts.com/dl/LobbyProtocol/ProtocolDescription.html#RING:client
  # extended to accept originator as a second argument (only allowed when sent by bots)
  # this allows spads to inform clients who originally rang them with spads-command !ring
  defp do_handle("RING", data, _msg_id, state) do
    case String.split(data) do
      [sender, originator] ->
        userid = CacheUser.get_userid(sender)
        client = Client.get_client_by_id(state.userid)

        if client != nil and CacheUser.is_bot?(state.userid) do
          originator_id = CacheUser.get_userid(originator)
          CacheUser.ring(userid, originator_id)
        end

      _ ->
        userid = CacheUser.get_userid(data)
        CacheUser.ring(userid, state.userid)
    end

    state
  end

  # Not handled catcher
  defp do_handle(cmd, data, msg_id, state) do
    _no_match(state, cmd, msg_id, data)
  end

  @spec _no_match(map(), String.t(), String.t() | nil, String.t()) :: map()
  def _no_match(state, cmd, msg_id, data) do
    data =
      data
      |> String.replace("\t", "\\t")

    msg =
      "No incomming match for #{cmd} with data '#{Kernel.inspect(data)}'. Userid #{state.userid}"

    Logger.info(msg)
    reply(:servermsg, msg, msg_id, state)
    state
  end

  @spec deny(map(), String.t()) :: map()
  defp deny(state, msg_id) do
    reply(:servermsg, "You do not have permission to execute that command", msg_id, state)
    state
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
        Logger.warning("status_flood_protection:10 - #{state.username}/#{state.userid}")
        {true, %{state | status_timestamps: status_timestamps}}

      Enum.count(recent_timestamps) > 3 ->
        Logger.warning("status_flood_protection:3 - #{state.username}/#{state.userid}")
        {true, %{state | status_timestamps: status_timestamps}}

      true ->
        {false, %{state | status_timestamps: status_timestamps}}
    end
  end

  @spec parse_in_message(String.t()) :: nil | {String.t(), String.t(), String.t()}
  def parse_in_message(raw) do
    ~r/^(#[0-9]+ )?([a-z_A-Z0-9\.]+)(.*)?$/u
    |> Regex.run(raw)
    |> _clean()
  end

  # @spec engage_flood_protection(map()) :: {:stop, String.t(), map()}
  # defp engage_flood_protection(state) do
  #   state.protocol_out.reply(:disconnect, "Spring status flood protection", nil, state)
  #   CacheUser.set_flood_level(state.userid, 10)
  #   Client.disconnect(state.userid, "SpringIn.status.flood_protection")
  #   Logger.error("Spring Status command overflow from #{state.username}/#{state.userid}")
  #   {:stop, "Spring status flood protection", state}
  # end
end
