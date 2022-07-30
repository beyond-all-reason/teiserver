defmodule Teiserver.Coordinator.CoordinatorCommands do
  alias Teiserver.{User, Account, Client, Coordinator}
  alias Teiserver.Battle.Lobby
  alias Teiserver.Data.Matchmaking
  alias Central.Helpers.NumberHelper
  alias Teiserver.Account.{AccoladeLib, CodeOfConductData}
  alias Teiserver.Coordinator.CoordinatorLib
  alias Central.Config

  @splitter "---------------------------"
  @always_allow ~w(help whoami whois discord coc ignore mute ignore unmute unignore 1v1me un1v1 website)
  @forward_to_consul ~w(s status players follow joinq leaveq splitlobby y yes n no)

  @spec allow_command?(Map.t(), Map.t()) :: boolean()
  defp allow_command?(%{senderid: senderid} = cmd, _state) do
    client = Client.get_client_by_id(senderid)

    cond do
      client == nil -> false
      Enum.member?(@forward_to_consul, cmd.command) -> true
      Enum.member?(@always_allow, cmd.command) -> true
      client.moderator == true -> true
      true -> false
    end
  end

  @spec handle_command(map(), map()) :: map()
  def handle_command(cmd, state) do
    cond do
      Enum.member?(@forward_to_consul, cmd.command) ->
        client = Client.get_client_by_id(cmd.senderid)
        if client.lobby_id do
          consul_pid = Coordinator.get_consul_pid(client.lobby_id)
          send(consul_pid, cmd)
        end
        state

      Enum.member?(@always_allow, cmd.command) == false ->
        User.send_direct_message(state.userid, cmd.senderid, "No command of name '#{cmd.command}'")
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
    user = User.get_user_by_id(senderid)
    host_id = Map.get(cmd, :host_id, nil)

    messages = CoordinatorLib.help(user, host_id == senderid, remaining)
    |> String.split("\n")

    say_command(cmd)
    Coordinator.send_to_user(senderid, messages)
    state
  end

  defp do_handle(%{command: "1v1me", senderid: senderid} = _cmd, state) do
    User.send_direct_message(state.userid, senderid, "The matchmaking test is over due to lack of interest. If you wish to resume testing please let Teifion know in the discord.")
    state
  end

  # defp do_handle(%{command: "1v1me", senderid: senderid} = _cmd, state) do
  #   case Matchmaking.add_user_to_queue(1, senderid) do
  #     :failed ->
  #       User.send_direct_message(state.userid, senderid, "You were not added to the queue")
  #     _ ->
  #       User.send_direct_message(state.userid, senderid, "You have been added to the queue. You can remove yourself by messaging me $un1v1")
  #   end

  #   state
  # end

  defp do_handle(%{command: "un1v1", senderid: senderid} = _cmd, state) do
    Matchmaking.remove_user_from_queue(1, senderid)
    User.send_direct_message(state.userid, senderid, "You have been removed from the queue")

    state
  end

  defp do_handle(%{command: "whoami", senderid: senderid} = _cmd, state) do
    sender = User.get_user_by_id(senderid)
    stats = Account.get_user_stat_data(senderid)

    player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
    spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
    rank_time = User.rank_time(senderid)

    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    profile_link = "https://#{host}/teiserver/profile/#{senderid}"

    accolades = AccoladeLib.get_player_accolades(senderid)
    accolades_string = if Config.get_site_config_cache("teiserver.Enable accolades") do
      case Map.keys(accolades) do
        [] ->
          "You currently have no accolades"

        _ ->
          badge_types = Account.list_badge_types(search: [id_list: Map.keys(accolades)])
          |> Map.new(fn bt -> {bt.id, bt} end)

          ["Your accolades are as follows:"] ++
            (accolades
            |> Enum.map(fn {bt_id, count} ->
              ">> #{count}x #{badge_types[bt_id].name}"
            end))
      end
    end

    ratings = Account.list_ratings(
      search: [
        user_id: sender.id
      ],
      preload: [:rating_type]
    )
      |> Enum.map(fn rating ->
        score = rating.rating_value
          |> NumberHelper.round(2)

        "#{rating.rating_type.name}: #{score}"
      end)
      |> Enum.sort

    msg = [
      @splitter,
      "You are #{sender.name}",
      "Profile link: #{profile_link}",
      "Time rank: #{sender.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
      "Skill ratings:",
      ratings,
      accolades_string
    ]
      |> List.flatten
      |> Enum.reject(fn l -> l == nil end)

    User.send_direct_message(state.userid, senderid, msg)
    state
  end

  defp do_handle(%{command: "whois", senderid: senderid, remaining: remaining} = _cmd, state) do
    case User.get_user_by_name(remaining) do
      nil ->
        User.send_direct_message(state.userid, senderid, "Unable to find a user with that name")
      user ->
        sender = User.get_user_by_id(senderid)
        stats = Account.get_user_stat_data(user.id)

        previous_names = (stats["previous_names"] || [])
          |> Enum.join(", ")

        host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
        profile_link = "https://#{host}/teiserver/profile/#{user.id}"

        standard_parts = [
          @splitter,
          "Found #{user.name}",
          (if previous_names != "", do: "Previous names: #{previous_names}"),
          "Profile link: #{profile_link}"
        ]

        mod_parts = if User.is_moderator?(sender) do
          player_hours = Map.get(stats, "player_minutes", 0)/60 |> round
          spectator_hours = Map.get(stats, "spectator_minutes", 0)/60 |> round
          rank_time = User.rank_time(user.id)

          smurfs = Account.smurf_search(user)
            |> Enum.map(fn {_key, users} -> users end)
            |> List.flatten
            |> Enum.map(fn %{user: user} -> user end)
            |> Enum.reject(fn %{id: id} -> id == user.id end)
            |> Enum.uniq
            |> Enum.map(fn %{name: name} -> name end)

          smurf_string = case smurfs do
            [] -> "No smurfs found"
            _ -> "Found smurfs named: #{Enum.join(smurfs, ", ")}"
          end

          ratings = Account.list_ratings(
            search: [
              user_id: user.id
            ],
            preload: [:rating_type]
          )
            |> Enum.map(fn rating ->
              score = rating.rating_value
                |> NumberHelper.round(2)

              "#{rating.rating_type.name}: #{score}"
            end)

          accolades_string = if Config.get_site_config_cache("teiserver.Enable accolades") do
            accolades = AccoladeLib.get_player_accolades(user.id)
            case Map.keys(accolades) do
              [] ->
                "They currently have no accolades"

              _ ->
                badge_types = Account.list_badge_types(search: [id_list: Map.keys(accolades)])
                |> Map.new(fn bt -> {bt.id, bt} end)

                ["Accolades as follows:"] ++
                  (accolades
                  |> Enum.map(fn {bt_id, count} ->
                    ">> #{count}x #{badge_types[bt_id].name}"
                  end))
            end
          end

          [
            "Rank: #{user.rank+1} with #{player_hours} player hours and #{spectator_hours} spectator hours for a rank hour count of #{rank_time}",
            smurf_string,
            accolades_string,
            ["Ratings: " | ratings]
          ]
        else
          []
        end# End of moderation if-statement

        msg = (standard_parts ++ mod_parts)
          |> List.flatten
          |> Enum.reject(fn l -> l == nil end)

        User.send_direct_message(state.userid, senderid, msg)
    end
    state
  end

  # Code of Conduct search
  defp do_handle(%{command: "coc", remaining: remaining, senderid: senderid} = _cmd, state) do
    search_term = remaining
      |> String.trim
      |> String.downcase()

    messages = CodeOfConductData.flat_data()
    |> Enum.filter(fn {_key, value} ->
      String.contains?(value |> String.downcase, search_term)
    end)
    |> Enum.map(fn {key, value} ->
      "#{key} - #{value}"
    end)

    if Enum.empty?(messages) do
      User.send_direct_message(state.userid, senderid, "No matches for '#{remaining}'")
    else
      User.send_direct_message(state.userid, senderid, messages)
    end

    state
  end

  defp do_handle(%{command: "discord", senderid: senderid} = _cmd, state) do
    sender = User.get_user_by_id(senderid)

    if sender.discord_id != nil do
      User.send_direct_message(state.userid, senderid, "You already have a discord account linked.")
    else
      code = :rand.uniform(899999) + 100000 |> to_string
      Central.cache_put(:discord_bridge_account_codes, senderid, code)

      User.send_direct_message(state.userid, senderid, [
        @splitter,
        "To link your discord account, message the the discord bot (Teiserver Bridge) with the message",
        "$discord #{senderid}-#{code}",
        "This code will expire after 5 minutes",
      ])
    end

    state
  end

  defp do_handle(%{command: "ignore"} = cmd, state), do: do_handle(%{cmd | command: "mute"}, state)
  defp do_handle(%{command: "mute", senderid: senderid, remaining: remaining} = _cmd, state) do
    case User.get_user_by_name(remaining) do
      nil ->
        Coordinator.send_to_user(senderid, "I am unable to find a user by the name of '#{remaining}'")
      user ->
        if User.is_moderator?(user) do
          Coordinator.send_to_user(senderid, "You cannot block moderators.")
        else
          User.ignore_user(senderid, user.id)
          Coordinator.send_to_user(senderid, "#{user.name} is now ignored, you can unmute them with the $unignore command or via the account section of the server website.")
        end
    end
    state
  end

  defp do_handle(%{command: "unignore"} = cmd, state), do: do_handle(%{cmd | command: "unmute"}, state)
  defp do_handle(%{command: "unmute", senderid: senderid, remaining: remaining} = _cmd, state) do
    case User.get_user_by_name(remaining) do
      nil ->
        Coordinator.send_to_user(senderid, "I am unable to find a user by the name of '#{remaining}'")
      user ->
        User.unignore_user(senderid, user.id)
        Coordinator.send_to_user(senderid, "#{user.name} is now un-ignored.")
    end
    state
  end

  defp do_handle(%{command: "website", senderid: senderid} = _cmd, state) do
    uuid = UUID.uuid1()
    client = Client.get_client_by_id(senderid)
    {:ok, _code} = Central.Account.create_code(%{
        value: uuid <> "$#{client.ip}",
        purpose: "one_time_login",
        expires: Timex.now() |> Timex.shift(minutes: 5),
        user_id: senderid
      })
    host = Application.get_env(:central, CentralWeb.Endpoint)[:url][:host]
    url = "https://#{host}/one_time_login/#{uuid}"

    Coordinator.send_to_user(senderid, "Your one-time login code is #{url} it will expire in 5 minutes and must be accessed from the same IP you are accessing the game.")
    state
  end

  # Moderator commands
  defp do_handle(%{command: command, senderid: senderid} = _cmd, state) do
    User.send_direct_message(state.userid, senderid, "I don't have a handler for the command '#{command}'")
    state
  end

  @spec command_as_message(Map.t()) :: String.t()
  defp command_as_message(cmd) do
    remaining = if Map.get(cmd, :remaining), do: " #{cmd.remaining}", else: ""
    error = if Map.get(cmd, :error), do: " Error: #{cmd.error}", else: ""

    "#{cmd.command}#{remaining}#{error}"
      |> String.trim
  end

  defp say_command(%{lobby_id: nil}), do: :ok
  defp say_command(%{lobby_id: lobby_id, senderid: senderid} = cmd) do
    message = "$ " <> command_as_message(cmd)
    Lobby.say(senderid, message, lobby_id)
  end
  defp say_command(_), do: :ok
end
