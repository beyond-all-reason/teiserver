defmodule Teiserver.Coordinator.CoordinatorCommands do
  alias Teiserver.{CacheUser, Account, Client, Coordinator, Moderation}
  alias Teiserver.Lobby
  alias Teiserver.Helper.NumberHelper
  alias Teiserver.Account.{AccoladeLib, CodeOfConductData}
  alias Teiserver.Coordinator.CoordinatorLib
  alias Teiserver.Config

  @splitter "---------------------------"
  @always_allow ~w(help whoami whois discord coc mute unmute ignore unignore website party)
  # These commands are handled by coordinator commands, but are not on the always allow list
  @mod_allow ~w(modparty unparty)
  @forward_to_consul ~w(s status players follow joinq leaveq splitlobby y yes n no explain)
  @admin_commands ~w(broadcast)

  def is_coordinator_command?(command) do
    # The list of allowed commands are now defined in this file
    # They used to be defined in consul_server.ex under @coordinator_bot variable
    Enum.member?(@always_allow, command) || Enum.member?(@mod_allow, command)
  end

  @spec allow_command?(map(), map()) :: boolean()
  defp allow_command?(%{senderid: senderid} = cmd, state) do
    client = Client.get_client_by_id(senderid)
    user = Account.get_user_by_id(senderid)

    is_admin = Enum.member?(user.roles, "Admin")

    cond do
      client == nil ->
        false

      Enum.member?(@forward_to_consul, cmd.command) ->
        true

      Enum.member?(@always_allow, cmd.command) ->
        true

      # Allow all commands for Admins
      is_admin ->
        true

      # Allow all except Admin only commands for moderators
      client.moderator and not Enum.member?(@admin_commands, cmd.command) ->
        true

      not Enum.member?(@always_allow ++ @forward_to_consul, cmd.command) ->
        CacheUser.send_direct_message(
          state.userid,
          cmd.senderid,
          "No command of name '#{cmd.command}'"
        )

        false

      true ->
        false
    end
  end

  @spec handle_command(map(), map()) :: map()
  def handle_command(cmd, state) do
    cond do
      Enum.member?(@forward_to_consul, cmd.command) ->
        client = Client.get_client_by_id(cmd.senderid)

        if client.lobby_id do
          Coordinator.send_consul(client.lobby_id, cmd)
        end

        state

      allow_command?(cmd, state) == true ->
        do_handle(cmd, state)

      true ->
        state
    end
  end

  # Public commands
  @spec do_handle(map(), map()) :: map()
  defp do_handle(%{command: "help", senderid: senderid, remaining: remaining} = cmd, state) do
    user = CacheUser.get_user_by_id(senderid)
    host_id = Map.get(cmd, :host_id, nil)

    messages =
      CoordinatorLib.help(user, host_id == senderid, remaining)
      |> String.split("\n")

    say_command(cmd)
    Coordinator.send_to_user(senderid, messages)
    state
  end

  defp do_handle(%{command: "party", senderid: senderid} = _cmd, state) do
    client = Account.get_client_by_id(senderid)

    {:ok, code} =
      Account.create_code(%{
        value: ExULID.ULID.generate(),
        purpose: "one_time_login",
        expires: Timex.now() |> Timex.shift(minutes: 5),
        user_id: senderid,
        metadata: %{
          ip: client.ip,
          redirect: "/teiserver/account/parties"
        }
      })

    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/one_time_login/#{code.value}"

    Coordinator.send_to_user(senderid, [
      "To access parties please use this link - #{url}",
      "You can use the $explain command to see how balance is being calculated and why you are/are not being teamed with your party",
      "We are working on handling it within the new client and protocol, the website is only a temporary measure."
    ])

    state
  end

  defp do_handle(%{command: "whoami", senderid: senderid} = _cmd, state) do
    sender = CacheUser.get_user_by_id(senderid)
    stats = Account.get_user_stat_data(senderid)

    # Hours should be rounded down to make it more
    # accurate for determining if a chevron threshold is reached
    total_hours = (Map.get(stats, "total_minutes", 0) / 60) |> trunc
    player_hours = (Map.get(stats, "player_minutes", 0) / 60) |> trunc
    spectator_hours = (Map.get(stats, "spectator_minutes", 0) / 60) |> trunc
    lobby_hours = (Map.get(stats, "lobby_minutes", 0) / 60) |> trunc

    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    profile_link = "https://#{host}/profile/#{senderid}"

    accolades = AccoladeLib.get_player_accolades(senderid)

    accolades_string =
      if Config.get_site_config_cache("teiserver.Enable accolades") do
        case Map.keys(accolades) do
          [] ->
            "You currently have no accolades"

          _ ->
            badge_types =
              Account.list_badge_types(search: [id_list: Map.keys(accolades)])
              |> Map.new(fn bt -> {bt.id, bt} end)

            ["Your accolades are as follows:"] ++
              (accolades
               |> Enum.map(fn {bt_id, count} ->
                 ">> #{count}x #{badge_types[bt_id].name}"
               end))
        end
      end

    ratings =
      Account.list_ratings(
        search: [
          user_id: sender.id,
          season: Teiserver.Game.MatchRatingLib.active_season()
        ],
        preload: [:rating_type]
      )
      |> Enum.map(fn rating ->
        rating_score =
          rating.rating_value
          |> NumberHelper.round(2)

        leaderboard_rating =
          rating.leaderboard_rating
          |> NumberHelper.round(2)

        "#{rating.rating_type.name} > Game: #{rating_score}, Leaderboard: #{leaderboard_rating}"
      end)
      |> Enum.sort()

    chevron_level = Map.get(stats, "rank", 0) + 1

    msg =
      [
        @splitter,
        "You are #{sender.name}",
        "#{total_hours} total hours (#{player_hours} h playing, #{spectator_hours} h spectating, #{lobby_hours} h in lobby)",
        "Profile link: #{profile_link}",
        "Chevron level: #{chevron_level}",
        "Skill ratings:",
        ratings,
        accolades_string
      ]
      |> List.flatten()
      |> Enum.reject(fn l -> l == nil end)

    CacheUser.send_direct_message(state.userid, senderid, msg)
    state
  end

  defp do_handle(%{command: "whois", senderid: senderid, remaining: remaining} = _cmd, state) do
    case CacheUser.get_user_by_name(remaining) do
      nil ->
        CacheUser.send_direct_message(
          state.userid,
          senderid,
          "Unable to find a user with that name"
        )

      user ->
        sender = CacheUser.get_user_by_id(senderid)
        stats = Account.get_user_stat_data(user.id)

        previous_names =
          (stats["previous_names"] || [])
          |> Enum.join(", ")

        actions =
          Moderation.list_actions(
            search: [
              target_id: user.id,
              expiry: "All active"
            ]
          )
          |> Enum.reject(fn action ->
            action.restrictions == ["Bridging"]
          end)

        moderation_data =
          if Enum.empty?(actions) do
            ["No moderation restrictions applied."]
          else
            action_text =
              actions
              |> Enum.map(fn a -> String.split(a.reason, "\n") end)

            [
              "This user currently has one or more restrictions applied to their account because:",
              action_text
            ]
          end

        host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
        profile_link = "https://#{host}/profile/#{user.id}"

        ratings =
          Account.list_ratings(
            search: [
              user_id: user.id,
              season: Teiserver.Game.MatchRatingLib.active_season()
            ],
            preload: [:rating_type]
          )
          |> Enum.map(fn rating ->
            rating_score =
              rating.rating_value
              |> NumberHelper.round(2)

            leaderboard_rating =
              rating.leaderboard_rating
              |> NumberHelper.round(2)

            "#{rating.rating_type.name} > Game: #{rating_score}, Leaderboard: #{leaderboard_rating}"
          end)
          |> Enum.sort()

        chevron_level = Map.get(stats, "rank", 0) + 1

        standard_parts = [
          @splitter,
          "Found #{user.name}",
          if(previous_names != "", do: "Previous names: #{previous_names}"),
          "Profile link: #{profile_link}",
          "Chevron level: #{chevron_level}",
          ["Ratings:" | ratings],
          moderation_data,
          @splitter
        ]

        mod_parts =
          if CacheUser.is_moderator?(sender) do
            # player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
            # spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
            # rank_time = CacheUser.rank_time(user.id)

            smurfs =
              Account.smurf_search(user)
              |> Enum.map(fn {_key, users} -> users end)
              |> List.flatten()
              |> Enum.map(fn %{user: user} -> user end)
              |> Enum.reject(fn %{id: id} -> id == user.id end)
              |> Enum.uniq()
              |> Enum.map(fn %{name: name} -> name end)

            smurf_string =
              case smurfs do
                [] -> "No smurfs found"
                _ -> "Found smurfs named: #{Enum.join(smurfs, ", ")}"
              end

            accolades_string =
              if Config.get_site_config_cache("teiserver.Enable accolades") do
                accolades = AccoladeLib.get_player_accolades(user.id)

                case Map.keys(accolades) do
                  [] ->
                    "They currently have no accolades"

                  _ ->
                    badge_types =
                      Account.list_badge_types(search: [id_list: Map.keys(accolades)])
                      |> Map.new(fn bt -> {bt.id, bt} end)

                    ["Accolades as follows:"] ++
                      (accolades
                       |> Enum.map(fn {bt_id, count} ->
                         ">> #{count}x #{badge_types[bt_id].name}"
                       end))
                end
              end

            [
              # "Rank: #{user.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
              smurf_string,
              accolades_string
            ]
          else
            []
          end

        # End of moderation if-statement

        msg =
          (standard_parts ++ mod_parts)
          |> List.flatten()
          |> Enum.reject(fn l -> l == nil end)

        CacheUser.send_direct_message(state.userid, senderid, msg)
    end

    state
  end

  # Code of Conduct search
  defp do_handle(%{command: "coc", remaining: remaining, senderid: senderid} = _cmd, state) do
    search_term =
      remaining
      |> String.trim()
      |> String.downcase()

    messages =
      CodeOfConductData.flat_data()
      |> Enum.filter(fn {_key, value} ->
        String.contains?(value |> String.downcase(), search_term)
      end)
      |> Enum.map(fn {key, value} ->
        "#{key} - #{value}"
      end)

    if Enum.empty?(messages) do
      CacheUser.send_direct_message(state.userid, senderid, "No matches for '#{remaining}'")
    else
      CacheUser.send_direct_message(state.userid, senderid, messages)
    end

    state
  end

  defp do_handle(%{command: "discord", senderid: senderid} = _cmd, state) do
    sender = CacheUser.get_user_by_id(senderid)

    if sender.discord_id != nil do
      CacheUser.send_direct_message(
        state.userid,
        senderid,
        "You already have a discord account linked; the discord link is: #{Application.get_env(:teiserver, Teiserver)[:discord]}"
      )
    else
      code = (:rand.uniform(899_999) + 100_000) |> to_string
      Teiserver.cache_put(:discord_bridge_account_codes, senderid, code)

      CacheUser.send_direct_message(state.userid, senderid, [
        @splitter,
        "To link your discord account, send a private message to Teiserver Bot on the BAR discord with the message:",
        "$discord #{senderid}-#{code}",
        "This code will expire after 5 minutes",
        "The discord link is: #{Application.get_env(:teiserver, Teiserver)[:discord]}"
      ])
    end

    state
  end

  defp do_handle(%{command: "ignore"} = cmd, state),
    do: do_handle(%{cmd | command: "mute"}, state)

  defp do_handle(%{command: "mute", senderid: senderid, remaining: remaining} = _cmd, state) do
    case CacheUser.get_user_by_name(remaining) do
      nil ->
        Coordinator.send_to_user(
          senderid,
          "I am unable to find a user by the name of '#{remaining}'"
        )

      user ->
        if CacheUser.is_moderator?(user) do
          Coordinator.send_to_user(senderid, "You cannot block moderators.")
        else
          Account.ignore_user(senderid, user.id)

          Coordinator.send_to_user(
            senderid,
            "#{user.name} is now ignored, you can unmute them with the $unignore command or via the account section of the server website."
          )
        end
    end

    state
  end

  defp do_handle(%{command: "unignore"} = cmd, state),
    do: do_handle(%{cmd | command: "unmute"}, state)

  defp do_handle(%{command: "unmute", senderid: senderid, remaining: remaining} = _cmd, state) do
    case CacheUser.get_user_by_name(remaining) do
      nil ->
        Coordinator.send_to_user(
          senderid,
          "I am unable to find a user by the name of '#{remaining}'"
        )

      user ->
        Account.reset_relationship_state(senderid, user.id)
        Coordinator.send_to_user(senderid, "#{user.name} is now un-ignored.")
    end

    state
  end

  defp do_handle(%{command: "modparty", senderid: senderid, remaining: targets} = _cmd, state) do
    targets
    |> String.split(" ")
    |> Enum.map(fn name ->
      name
      |> String.trim()
      |> String.downcase()
    end)
    |> Enum.uniq()
    |> Enum.reduce(nil, fn target, party_id ->
      case CacheUser.get_userid(target) do
        nil ->
          CacheUser.send_direct_message(
            state.userid,
            senderid,
            "Unable to find a user '#{target}'"
          )

          party_id

        target_id ->
          party_id =
            if party_id do
              Account.create_party_invite(party_id, target_id)
              Account.accept_party_invite(party_id, target_id)
              # Account.move_client_to_party(target_id, party_id)
              party_id
            else
              party = Account.create_party(target_id)
              party.id
            end

          :timer.sleep(50)

          party_id
      end
    end)

    state
  end

  defp do_handle(%{command: "unparty", remaining: targets} = _cmd, state) do
    targets
    |> String.split(" ")
    |> Enum.map(fn name ->
      name
      |> String.trim()
      |> String.downcase()
    end)
    |> Enum.uniq()
    |> Enum.reduce(nil, fn target, _ ->
      case CacheUser.get_userid(target) do
        nil ->
          :ok

        target_id ->
          client = Account.get_client_by_id(target_id)

          if client.party_id do
            Account.leave_party(client.party_id, target_id)
            Account.move_client_to_party(target_id, nil)
          end
      end
    end)

    state
  end

  defp do_handle(%{command: "website", senderid: senderid} = _cmd, state) do
    client = Client.get_client_by_id(senderid)

    {:ok, code} =
      Account.create_code(%{
        value: ExULID.ULID.generate(),
        purpose: "one_time_login",
        expires: Timex.now() |> Timex.shift(minutes: 5),
        user_id: senderid,
        metadata: %{ip: client.ip}
      })

    host = Application.get_env(:teiserver, TeiserverWeb.Endpoint)[:url][:host]
    url = "https://#{host}/one_time_login/#{code.value}"

    Coordinator.send_to_user(
      senderid,
      "Your one-time login link is #{url} it will expire in 5 minutes and must be accessed from the same IP you are accessing the game."
    )

    state
  end

  # Admin commands
  defp do_handle(
         %{command: "broadcast", senderid: senderid, remaining: message},
         state
       ) do
    Lobby.list_lobby_ids()
    |> Enum.each(fn lobby_id ->
      Lobby.say(senderid, message, lobby_id)
    end)

    state
  end

  # Moderator commands
  defp do_handle(%{command: command, senderid: senderid} = _cmd, state) do
    CacheUser.send_direct_message(
      state.userid,
      senderid,
      "I don't have a handler for the command '#{command}'"
    )

    state
  end

  @spec command_as_message(map()) :: String.t()
  defp command_as_message(cmd) do
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{cmd.command}#{remaining}#{error}"
    |> String.trim()
  end

  defp say_command(%{lobby_id: nil}), do: :ok

  defp say_command(%{lobby_id: lobby_id, senderid: senderid} = cmd) do
    message = "$ " <> command_as_message(cmd)
    Lobby.say(senderid, message, lobby_id)
  end

  defp say_command(_), do: :ok
end
