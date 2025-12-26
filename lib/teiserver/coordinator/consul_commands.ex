defmodule Teiserver.Coordinator.ConsulCommands do
  @moduledoc false
  require Logger
  alias Teiserver.Config
  alias Teiserver.Coordinator.{ConsulServer, RikerssMemes}
  alias Teiserver.{Account, Battle, Lobby, Coordinator, CacheUser, Client, Telemetry}
  alias Teiserver.Lobby.{ChatLib, LobbyLib, LobbyRestrictions}
  alias Teiserver.Chat.WordLib
  alias Teiserver.Battle.BalanceLib
  alias Teiserver.Data.Types, as: T
  import Teiserver.Helper.NumberHelper, only: [int_parse: 1, round: 2]

  @doc """
    Command has structure:
    %{
      raw: string,
      remaining: string,
      command: nil | string,
      senderid: userid
    }
  """
  @splitter "------------------------------------------------------"
  @split_delay 60_000
  @spec handle_command(map(), map()) :: map()
  @default_ban_reason "Banned"

  #################### For everybody
  def handle_command(%{command: "s"} = cmd, state),
    do: handle_command(Map.put(cmd, :command, "status"), state)

  def handle_command(%{command: "status", senderid: senderid} = _cmd, state) do
    locks =
      state.locks
      |> Enum.map_join(", ", fn l -> to_string(l) end)

    queue = get_queue(state)

    pos_str =
      case get_queue_position(queue, senderid) do
        -1 ->
          nil

        pos ->
          if Enum.member?(state.low_priority_join_queue, senderid) do
            "You are at position #{pos + 1} but in the low priority queue so other users may be added in front of you"
          else
            "You are at position #{pos + 1} in the queue"
          end
      end

    queue_string =
      queue
      |> Enum.map_join(", ", &CacheUser.get_username/1)

    queue_size = Enum.count(queue)

    player_count = Battle.get_lobby_player_count(state.lobby_id)

    max_player_count = ConsulServer.get_max_player_count(state)

    boss_string =
      case state.host_bosses do
        [] ->
          "Nobody is bossed"

        [boss_id] ->
          "Host boss is: #{CacheUser.get_username(boss_id)}"

        boss_ids ->
          boss_names =
            boss_ids
            |> Enum.map_join(", ", fn b -> CacheUser.get_username(b) end)

          "Host bosses are: #{boss_names}"
      end

    tourney_mode =
      if state.tournament_lobby do
        "Tournament mode is enabled"
      end

    # Party info
    parties =
      Battle.list_lobby_players(state.lobby_id)
      |> Enum.group_by(
        fn p -> p.party_id end,
        fn p -> p.name end
      )
      |> Map.drop([nil])
      |> Enum.filter(fn {_id, members} -> Enum.count(members) > 1 end)
      |> Enum.map(fn {_id, members} -> members end)

    party_text =
      if Enum.empty?(parties) do
        []
      else
        party_list =
          parties
          |> Enum.map(fn members ->
            "> #{Enum.join(members, ", ")}"
          end)

        ["Parties:" | party_list]
      end

    play_level_bounds = LobbyRestrictions.get_rating_bounds_for_title(state)
    play_rank_bounds = LobbyRestrictions.get_rank_bounds_for_title(state)

    welcome_message =
      if state.welcome_message do
        ["Welcome message: "] ++ String.split(state.welcome_message, "$$")
      end

    # Put other settings in here
    other_settings =
      [
        welcome_message,
        "Currently #{player_count} players",
        "Team size and count are: #{state.host_teamsize} and #{state.host_teamcount}",
        "Balance algorithm is: #{state.balance_algorithm}",
        boss_string,
        tourney_mode,
        "Maximum allowed number of players is #{max_player_count} (Host = #{state.host_teamsize * state.host_teamcount}, Coordinator = #{state.player_limit})",
        play_level_bounds,
        play_rank_bounds
      ]
      |> List.flatten()
      |> Enum.filter(fn v -> v != nil end)

    status_msg =
      [
        @splitter,
        "Lobby status",
        @splitter,
        "Status for battle ##{state.lobby_id}",
        "Locks: #{locks}",
        "Gatekeeper: #{state.gatekeeper}",
        party_text,
        pos_str,
        "Join queue: #{queue_string} (size: #{queue_size})",
        other_settings
      ]
      |> List.flatten()
      |> Enum.filter(fn s -> s != nil end)

    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "roll", remaining: remaining, senderid: senderid} = _cmd, state) do
    username = CacheUser.get_username(senderid)

    dice_regex = Regex.run(~r/^(\d+)[dD](\d+)$/, remaining)
    max_format = Regex.run(~r/^(\d+)$/, remaining)
    min_max_format = Regex.run(~r/^(\d+) (\d+)$/, remaining)

    cond do
      dice_regex != nil ->
        [_all, n_dice, s_dice] = dice_regex
        n_dice = int_parse(n_dice) |> max(1) |> min(100)
        s_dice = int_parse(s_dice) |> max(1) |> min(100)

        result =
          Range.new(1, n_dice)
          |> Enum.map(fn _ -> :rand.uniform(s_dice) end)
          |> Enum.sum()

        ChatLib.say(
          state.coordinator_id,
          "#{username} rolled #{n_dice}D#{s_dice} and got a result of: #{result}",
          state.lobby_id
        )

      max_format != nil ->
        [_all, smax] = max_format
        nmax = int_parse(smax)

        if nmax > 0 do
          result = :rand.uniform(nmax)

          ChatLib.say(
            state.coordinator_id,
            "#{username} rolled for a number between 1 and #{nmax}, they got: #{result}",
            state.lobby_id
          )
        else
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "Format not recognised, please consult the help for this command for more information.",
            state.lobby_id
          )
        end

      min_max_format != nil ->
        [_all, smin, smax] = min_max_format
        nmin = int_parse(smin)
        nmax = int_parse(smax)

        if nmax > nmin and nmin > 0 do
          result = nmin + :rand.uniform(nmax - nmin)

          ChatLib.say(
            state.coordinator_id,
            "#{username} rolled for a number between #{nmin} and #{nmax}, they got: #{result}",
            state.lobby_id
          )
        else
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "Format not recognised, please consult the help for this command for more information.",
            state.lobby_id
          )
        end

      true ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "Format not recognised, please consult the help for this command for more information.",
          state.lobby_id
        )
    end

    state
  end

  def handle_command(%{command: "tournament", senderid: senderid, remaining: rem} = cmd, state) do
    if Config.get_site_config_cache("teiserver.Allow tournament command") do
      if CacheUser.has_any_role?(senderid, [
           "Moderator",
           "Caster",
           "Tournament player",
           "TourneyPlayer"
         ]) do
        if rem |> String.trim() |> String.downcase() == "off" do
          Battle.update_lobby_values(state.lobby_id, %{tournament: false})
          state = %{state | tournament_lobby: false}
          ConsulServer.say_command(cmd, state)
        else
          Battle.update_lobby_values(state.lobby_id, %{tournament: true})
          # ChatLib.say(senderid, "!preset tourney", state.lobby_id)
          send(self(), :recheck_membership)
          state = %{state | tournament_lobby: true}
          ConsulServer.say_command(cmd, state)
        end
      else
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "Only casters, tournament players and moderators can set tournament mode.",
          state.lobby_id
        )

        state
      end
    else
      Battle.update_lobby_values(state.lobby_id, %{tournament: false})

      ChatLib.sayprivateex(
        state.coordinator_id,
        senderid,
        "Tournament mode has been removed from this lobby.",
        state.lobby_id
      )

      %{state | tournament_lobby: false}
    end
  end

  def handle_command(%{command: "afks", senderid: senderid} = cmd, state) do
    min_diff_ms = 20_000
    max_diff_s = 300
    now = System.system_time(:millisecond)
    lobby = Lobby.get_lobby(state.lobby_id)

    if lobby.in_progress do
      Coordinator.send_to_user(
        senderid,
        "The game is currently in progress, we cannot check for AFK at this time"
      )
    else
      lines =
        state.last_seen_map
        |> Enum.filter(fn {userid, seen_at} ->
          Enum.member?(lobby.players, userid) and now - seen_at > min_diff_ms
        end)
        |> Enum.filter(fn {userid, _seen_at} ->
          Client.get_client_by_id(userid).player
        end)
        |> Enum.map(fn {userid, seen_at} ->
          seconds_ago = ((now - seen_at) / 1000) |> round()
          {userid, seconds_ago}
        end)
        |> Enum.sort_by(fn {_userid, seconds_ago} -> seconds_ago end, &<=/2)
        |> Enum.map(fn {userid, seconds_ago} ->
          if seconds_ago > max_diff_s do
            "#{CacheUser.get_username(userid)} is almost certainly afk"
          else
            "#{CacheUser.get_username(userid)} last seen #{seconds_ago}s ago"
          end
        end)

      case lines do
        [] ->
          Coordinator.send_to_user(senderid, "No afk users found")

        _ ->
          Coordinator.send_to_user(
            senderid,
            [@splitter, "The following users may be afk"] ++ lines
          )
      end
    end

    ConsulServer.say_command(cmd, state)
    state
  end

  def handle_command(
        %{command: "splitlobby", remaining: rem, senderid: senderid} = cmd,
        %{split: nil} = state
      ) do
    ConsulServer.say_command(cmd, state)
    sender_name = CacheUser.get_username(senderid)

    min_players =
      case String.trim(rem) do
        "" ->
          1

        _ ->
          rem
          |> String.trim()
          |> String.to_integer()
          |> max(1)
      end

    ChatLib.sayex(
      state.coordinator_id,
      "Split lobby sequence started ($y to move, $n to cancel, $follow <name> to follow user)",
      state.lobby_id
    )

    Lobby.list_lobby_players!(state.lobby_id)
    |> Enum.each(fn playerid ->
      CacheUser.send_direct_message(state.coordinator_id, playerid, [
        @splitter,
        "#{sender_name} is moving to a new lobby, to follow them say $y.",
        "If you want to follow someone else then say $follow <name> and you will follow that user.",
        "The split will take place in #{round(@split_delay / 1_000)} seconds if at least #{min_players} player(s) agree to move.",
        "You can change your mind at any time. Say $n to cancel your decision and stay here.",
        @splitter
      ])
    end)

    CacheUser.send_direct_message(state.coordinator_id, senderid, [
      "Splitlobby sequence started. If you stay in this lobby you will be moved to a random empty lobby.",
      "If you choose a lobby yourself then anybody voting yes will follow you to that lobby.",
      @splitter
    ])

    split_uuid = ExULID.ULID.generate()

    new_split = %{
      split_uuid: split_uuid,
      first_splitter_id: senderid,
      splitters: %{},
      min_players: min_players
    }

    Logger.info("Started split lobby #{Kernel.inspect(new_split)}")

    :timer.send_after(@split_delay, {:do_split, split_uuid})
    %{state | split: new_split}
  end

  def handle_command(%{command: "splitlobby", senderid: senderid} = _cmd, state) do
    ChatLib.sayprivateex(
      state.coordinator_id,
      senderid,
      "A split is already underway, you cannot start a new one yet",
      state.lobby_id
    )

    state
  end

  # Split commands for when there is no split happening
  def handle_command(%{command: "y"}, %{split: nil} = state), do: state
  def handle_command(%{command: "n"}, %{split: nil} = state), do: state
  def handle_command(%{command: "follow"}, %{split: nil} = state), do: state

  # And for when it is
  def handle_command(%{command: "n", senderid: senderid} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    Logger.info("Split.n from #{senderid}")

    new_splitters = Map.delete(state.split.splitters, senderid)
    new_split = %{state.split | splitters: new_splitters}
    %{state | split: new_split}
  end

  def handle_command(%{command: "y", senderid: senderid} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    Logger.info("Split.y from #{senderid}")

    new_splitters = Map.put(state.split.splitters, senderid, true)
    new_split = %{state.split | splitters: new_splitters}
    %{state | split: new_split}
  end

  def handle_command(%{command: "follow", remaining: target, senderid: senderid} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)

      player_id ->
        ConsulServer.say_command(cmd, state)
        Logger.info("Split.follow from #{senderid}")

        new_splitters =
          if player_id == state.split.first_splitter_id do
            Map.put(state.split.splitters, senderid, true)
          else
            Map.put(state.split.splitters, senderid, player_id)
          end

        new_split = %{state.split | splitters: new_splitters}
        %{state | split: new_split}
    end
  end

  def handle_command(%{command: "explain", senderid: senderid} = cmd, state) do
    balance =
      state.lobby_id
      |> Battle.get_lobby_current_balance()

    if balance do
      moderator_messages =
        if CacheUser.is_moderator?(senderid) do
          time_taken =
            cond do
              balance.time_taken < 1000 ->
                "Time taken: #{balance.time_taken}us"

              balance.time_taken < 1000_000 ->
                t = round(balance.time_taken / 1000)
                "Time taken: #{t}ms"

              balance.time_taken < 1000_000_000 ->
                t = round(balance.time_taken / 1000_000)
                "Time taken: #{t}s"
            end

          [
            time_taken
          ]
        else
          []
        end

      team_stats =
        balance.team_sizes
        |> Map.keys()
        |> Enum.sort()
        |> Enum.map(fn team_id ->
          # We default them to 0 because it's possible there is no data for a team
          # if it's empty
          sum = (balance.ratings[team_id] || 0) |> round(1)
          mean = (balance.means[team_id] || 0) |> round(1)
          stdev = (balance.stdevs[team_id] || 0) |> round(2)
          "Team #{team_id} - sum: #{sum}, mean: #{mean}, stdev: #{stdev}"
        end)

      Coordinator.send_to_user(
        senderid,
        [
          @splitter,
          "Balance logs, mode: #{balance.balance_mode}",
          balance.logs,
          "Deviation of: #{balance.deviation}",
          team_stats,
          moderator_messages,
          @splitter
        ]
        |> List.flatten()
      )

      ConsulServer.say_command(cmd, state)
    else
      Coordinator.send_to_user(senderid, [
        @splitter,
        "No balance has been created for this room",
        @splitter
      ])
    end

    state
  end

  def handle_command(%{command: "joinq", senderid: senderid} = _cmd, state) do
    client = Client.get_client_by_id(senderid)

    cond do
      client == nil ->
        state

      CacheUser.is_restricted?(senderid, ["Game queue"]) ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "You are restricted from joining from joining the queue",
          state.lobby_id
        )

        state

      client.player ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "You are already a player, you can't join the queue!",
          state.lobby_id
        )

        state

      Enum.member?(get_queue(state), senderid) ->
        pos = get_queue_position(get_queue(state), senderid) + 1

        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "You were already in the join-queue at position #{pos}. Use $status to check on the queue and $leaveq to leave it.",
          state.lobby_id
        )

        state

      true ->
        send(self(), :queue_check)

        new_state =
          if CacheUser.is_restricted?(senderid, ["Low priority"]) do
            %{state | low_priority_join_queue: state.low_priority_join_queue ++ [senderid]}
          else
            %{state | join_queue: state.join_queue ++ [senderid]}
          end

        ConsulServer.queue_size_changed(new_state)

        new_queue = get_queue(new_state)
        pos = get_queue_position(new_queue, senderid) + 1

        if CacheUser.is_restricted?(senderid, ["Low priority"]) do
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "You are now in the low priority join-queue at position #{pos}, this means you will be added to the game after normal-priority members. Use $status to check on the queue.",
            state.lobby_id
          )
        else
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "You are now in the join-queue at position #{pos}. Use $status to check on the queue.",
            state.lobby_id
          )
        end

        new_state
    end
  end

  def handle_command(%{command: "leaveq", senderid: senderid}, state) do
    if Enum.member?(get_queue(state), senderid) do
      ChatLib.sayprivateex(
        state.coordinator_id,
        senderid,
        "You have been removed from the join queue",
        state.lobby_id
      )

      %{
        state
        | join_queue: state.join_queue |> List.delete(senderid),
          low_priority_join_queue: state.low_priority_join_queue |> List.delete(senderid)
      }
      |> ConsulServer.queue_size_changed()
    else
      state
    end
  end

  def handle_command(%{command: "password?", senderid: senderid}, state) do
    case Battle.get_lobby(state.lobby_id) do
      %{passworded: false} ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "This lobby has no password set",
          state.lobby_id
        )

      %{password: password} ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "The lobby password is currently: #{password}",
          state.lobby_id
        )
    end

    state
  end

  #################### Boss
  def handle_command(
        %{command: "balancealgorithm", remaining: "default", senderid: senderid},
        state
      ) do
    default_algo = BalanceLib.get_default_algorithm()

    handle_command(
      %{command: "balancealgorithm", remaining: default_algo, senderid: senderid},
      state
    )
  end

  def handle_command(
        %{command: "balancealgorithm", remaining: remaining, senderid: senderid},
        state
      ) do
    remaining =
      remaining
      |> String.downcase()
      |> String.trim()

    is_moderator = CacheUser.is_moderator?(senderid)

    allowed_choices = Teiserver.Battle.BalanceLib.get_allowed_algorithms(is_moderator)

    if Enum.member?(allowed_choices, remaining) do
      ChatLib.say(
        state.coordinator_id,
        "Balance algorithm set to #{remaining}",
        state.lobby_id
      )

      Coordinator.cast_balancer(state.lobby_id, {:set_algorithm, remaining})
      %{state | balance_algorithm: remaining}
    else
      ChatLib.say(
        state.coordinator_id,
        "No balance algorithm of #{remaining}. Options are: #{allowed_choices |> Enum.join(", ")}",
        state.lobby_id
      )

      state
    end
  end

  def handle_command(%{command: "gatekeeper", remaining: mode, senderid: senderid} = cmd, state) do
    state =
      case mode do
        "friends" ->
          ChatLib.say(
            state.coordinator_id,
            "Gatekeeper mode set to friends, only friends of a player can join the lobby",
            state.lobby_id
          )

          %{state | gatekeeper: :friends}

        "friendsplay" ->
          ChatLib.say(
            state.coordinator_id,
            "Gatekeeper mode set to friendsplay, only friends of a player can play in the lobby (anybody can join)",
            state.lobby_id
          )

          %{state | gatekeeper: :friendsplay}

        "default" ->
          ChatLib.say(state.coordinator_id, "Gatekeeper reset", state.lobby_id)
          %{state | gatekeeper: :default}

        _ ->
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "No gatekeeper of that type (accepted types are: friends, friendsplay)",
            state.lobby_id
          )

          state
      end

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "welcome-message", remaining: remaining} = cmd, state) do
    new_state =
      case String.trim(remaining) do
        "" ->
          %{state | welcome_message: nil}

        msg ->
          ConsulServer.say_command(cmd, state)
          Lobby.sayex(state.coordinator_id, "New welcome message set to: #{msg}", state.lobby_id)
          %{state | welcome_message: msg}
      end

    ConsulServer.broadcast_update(new_state)
  end

  def handle_command(%{command: "reset_approval"} = cmd, state) do
    players = Lobby.list_lobby_players!(state.lobby_id)
    new_state = %{state | approved_users: players}
    ConsulServer.say_command(cmd, new_state)
  end

  def handle_command(%{command: "resetratinglevels", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

    %{
      state
      | minimum_rating_to_play: 0,
        maximum_rating_to_play: LobbyRestrictions.rating_upper_bound()
    }
  end

  def handle_command(%{command: "resetchevlevels", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_rank_to_play: 0, maximum_rank_to_play: LobbyRestrictions.rank_upper_bound()}
  end

  # Reset min chev level for a lobby by using empty argument
  def handle_command(%{command: "minchevlevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_rank_to_play: 0}
  end

  # Set min chev level for a lobby
  def handle_command(
        %{command: "minchevlevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    result = LobbyRestrictions.allowed_to_set_restrictions(state)

    case result do
      :ok ->
        # Allowed to set restrictions
        case Integer.parse(remaining |> String.trim()) do
          :error ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{remaining}' into an integer"
              ],
              state.lobby_id
            )

            state

          {chev_level, _} ->
            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
            Process.send_after(self(), :recheck_membership, 0)
            level = chev_level - 1

            Map.merge(state, %{
              minimum_rank_to_play: level,
              maximum_rank_to_play: LobbyRestrictions.rank_upper_bound()
            })
        end

      # Not Allowed to set restrictions
      {:error, error_msg} ->
        Lobby.sayex(
          state.coordinator_id,
          error_msg,
          state.lobby_id
        )

        state
    end
  end

  # Reset max chev level for a lobby by using empty argument
  def handle_command(%{command: "maxchevlevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | maximum_rank_to_play: LobbyRestrictions.rank_upper_bound()}
  end

  # Setting max chev level we reset min chev level
  def handle_command(
        %{command: "maxchevlevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    result = LobbyRestrictions.allowed_to_set_restrictions(state)

    case result do
      :ok ->
        case Integer.parse(remaining |> String.trim()) do
          :error ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{remaining}' into an integer"
              ],
              state.lobby_id
            )

            state

          {chev_level, _} ->
            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
            Process.send_after(self(), :recheck_membership, 0)
            level = chev_level - 1

            Map.merge(state, %{
              maximum_rank_to_play: level,
              minimum_rank_to_play: 0
            })
        end

      {:error, error_msg} ->
        Lobby.sayex(
          state.coordinator_id,
          error_msg,
          state.lobby_id
        )

        error_msg
    end
  end

  def handle_command(%{command: "minratinglevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_rating_to_play: 0}
  end

  def handle_command(
        %{command: "minratinglevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    result = LobbyRestrictions.allowed_to_set_restrictions(state)

    case result do
      :ok ->
        case Integer.parse(remaining |> String.trim()) do
          :error ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{remaining}' into an integer"
              ],
              state.lobby_id
            )

            state

          {level, _} ->
            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
            Process.send_after(self(), :recheck_membership, 0)

            Map.merge(state, %{
              minimum_rating_to_play: level |> max(0) |> min(state.maximum_rating_to_play - 1)
            })
        end

      {:error, error_msg} ->
        Lobby.sayex(
          state.coordinator_id,
          error_msg,
          state.lobby_id
        )

        state
    end
  end

  def handle_command(%{command: "maxratinglevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | maximum_rating_to_play: LobbyRestrictions.rating_upper_bound()}
  end

  def handle_command(
        %{command: "maxratinglevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    result = LobbyRestrictions.allowed_to_set_restrictions(state)

    case result do
      :ok ->
        case Integer.parse(remaining |> String.trim()) do
          :error ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{remaining}' into an integer"
              ],
              state.lobby_id
            )

            state

          {level, _} ->
            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
            Process.send_after(self(), :recheck_membership, 0)

            %{
              state
              | maximum_rating_to_play:
                  level |> min(1000) |> max(state.minimum_rating_to_play + 1)
            }
        end

      {:error, error_msg} ->
        Lobby.sayex(
          state.coordinator_id,
          error_msg,
          state.lobby_id
        )

        state
    end
  end

  def handle_command(
        %{command: "setratinglevels", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case String.split(remaining, " ") do
      [smin, smax] ->
        case {Integer.parse(smin |> String.trim()), Integer.parse(smax |> String.trim())} do
          {:error, _} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smin}' into an integer"
              ],
              state.lobby_id
            )

            state

          {_, :error} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smax}' into an integer"
              ],
              state.lobby_id
            )

            state

          {{min_level_o, _}, {max_level_o, _}} ->
            result = LobbyRestrictions.allowed_to_set_restrictions(state)

            case result do
              :ok ->
                min_level = min(min_level_o, max_level_o)
                max_level = max(min_level_o, max_level_o)

                ConsulServer.say_command(cmd, state)
                LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
                Process.send_after(self(), :recheck_membership, 0)

                %{
                  state
                  | minimum_rating_to_play: max(min_level, 0),
                    maximum_rating_to_play: min(max_level, 1000)
                }

              {:error, error_msg} ->
                Lobby.sayex(
                  state.coordinator_id,
                  error_msg,
                  state.lobby_id
                )

                state
            end
        end

      _ ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "setplaylevels takes two numbers, no more no less"
          ],
          state.lobby_id
        )

        state
    end
  end

  def handle_command(%{command: "resetranklevels", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_rank_to_play: 0, maximum_rank_to_play: 1000}
  end

  def handle_command(%{command: "minranklevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_rank_to_play: 0}
  end

  def handle_command(
        %{command: "minranklevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case Integer.parse(remaining |> String.trim()) do
      :error ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "Unable to turn '#{remaining}' into an integer"
          ],
          state.lobby_id
        )

        state

      {level, _} ->
        ConsulServer.say_command(cmd, state)
        LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
        %{state | minimum_rank_to_play: level |> max(0) |> min(state.maximum_rank_to_play - 1)}
    end
  end

  def handle_command(%{command: "maxranklevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | maximum_rank_to_play: 1000}
  end

  def handle_command(
        %{command: "maxranklevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case Integer.parse(remaining |> String.trim()) do
      :error ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "Unable to turn '#{remaining}' into an integer"
          ],
          state.lobby_id
        )

        state

      {level, _} ->
        ConsulServer.say_command(cmd, state)
        LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

        %{
          state
          | maximum_rank_to_play:
              level
              |> min(LobbyRestrictions.rating_upper_bound())
              |> max(state.minimum_rank_to_play + 1)
        }
    end
  end

  def handle_command(
        %{command: "setranklevels", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case String.split(remaining, " ") do
      [smin, smax] ->
        case {Integer.parse(smin |> String.trim()), Integer.parse(smax |> String.trim())} do
          {:error, _} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smin}' into an integer"
              ],
              state.lobby_id
            )

            state

          {_, :error} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smax}' into an integer"
              ],
              state.lobby_id
            )

            state

          {{min_level_o, _}, {max_level_o, _}} ->
            min_level = min(min_level_o, max_level_o)
            max_level = max(min_level_o, max_level_o)

            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

            %{
              state
              | minimum_rank_to_play: max(min_level, 0),
                maximum_rank_to_play: min(max_level, LobbyRestrictions.rank_upper_bound())
            }
        end

      _ ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "setranklevels takes two numbers, no more no less"
          ],
          state.lobby_id
        )

        state
    end
  end

  def handle_command(%{command: "resetuncertaintylevels", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_uncertainty_to_play: 0, maximum_uncertainty_to_play: 1000}
  end

  def handle_command(%{command: "minuncertaintylevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | minimum_uncertainty_to_play: 0}
  end

  def handle_command(
        %{command: "minuncertaintylevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case Integer.parse(remaining |> String.trim()) do
      :error ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "Unable to turn '#{remaining}' into an integer"
          ],
          state.lobby_id
        )

        state

      {level, _} ->
        ConsulServer.say_command(cmd, state)
        LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

        %{
          state
          | minimum_uncertainty_to_play:
              level |> max(0) |> min(state.maximum_uncertainty_to_play - 1)
        }
    end
  end

  def handle_command(%{command: "maxuncertaintylevel", remaining: ""} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    %{state | maximum_uncertainty_to_play: 1000}
  end

  def handle_command(
        %{command: "maxuncertaintylevel", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case Integer.parse(remaining |> String.trim()) do
      :error ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "Unable to turn '#{remaining}' into an integer"
          ],
          state.lobby_id
        )

        state

      {level, _} ->
        ConsulServer.say_command(cmd, state)
        LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

        %{
          state
          | maximum_uncertainty_to_play:
              level |> min(1000) |> max(state.minimum_uncertainty_to_play + 1)
        }
    end
  end

  def handle_command(
        %{command: "setuncertaintylevels", remaining: remaining, senderid: senderid} = cmd,
        state
      ) do
    case String.split(remaining, " ") do
      [smin, smax] ->
        case {Integer.parse(smin |> String.trim()), Integer.parse(smax |> String.trim())} do
          {:error, _} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smin}' into an integer"
              ],
              state.lobby_id
            )

            state

          {_, :error} ->
            Lobby.sayprivateex(
              state.coordinator_id,
              senderid,
              [
                "Unable to turn '#{smax}' into an integer"
              ],
              state.lobby_id
            )

            state

          {{min_level_o, _}, {max_level_o, _}} ->
            min_level = min(min_level_o, max_level_o)
            max_level = max(min_level_o, max_level_o)

            ConsulServer.say_command(cmd, state)
            LobbyLib.cast_lobby(state.lobby_id, :refresh_name)

            %{
              state
              | minimum_uncertainty_to_play: max(min_level, 0),
                maximum_uncertainty_to_play: min(max_level, 1000)
            }
        end

      _ ->
        Lobby.sayprivateex(
          state.coordinator_id,
          senderid,
          [
            "setuncertaintylevels takes two numbers, no more no less"
          ],
          state.lobby_id
        )

        state
    end
  end

  #################### VIP Streamer
  def handle_command(%{command: "shuffle", remaining: remaining, senderid: senderid}, state) do
    mode =
      case String.downcase(remaining) do
        "party" ->
          "party"

        "friends" ->
          "friends"

        "contributor" ->
          "contributor"

        "dev" ->
          "dev"

        "admin" ->
          "admin"

        "all" ->
          "all"

        "default" ->
          "default"

        _ ->
          ChatLib.sayprivateex(
            state.coordinator_id,
            senderid,
            "Shuffle types are party, friends, contributor, dev, admin, all and default; using 'default'",
            state.lobby_id
          )

          "default"
      end

    lobby = Lobby.get_lobby(state.lobby_id)

    players =
      lobby.players
      |> Enum.map(fn player_id ->
        Client.get_client_by_id(player_id)
      end)
      |> Enum.reject(&(&1 == nil))
      |> Enum.filter(fn client ->
        client.player
      end)

    queuers =
      state.join_queue
      |> Enum.map(fn player_id ->
        Client.get_client_by_id(player_id)
      end)
      |> Enum.reject(&(&1 == nil))

    all_possible_clients = players ++ queuers

    # Generate a map of true and false, true are players and false is the queue
    result =
      case mode do
        "party" ->
          sender_party = Client.get_client_by_id(senderid) |> Map.get(:party_id)

          all_possible_clients
          |> Enum.group_by(
            fn client ->
              client.party_id == sender_party
            end,
            fn %{userid: userid} ->
              userid
            end
          )

        "friends" ->
          sender_friends = [senderid | CacheUser.get_user_by_id(senderid) |> Map.get(:friends)]

          all_possible_clients
          |> Enum.group_by(
            fn %{userid: userid} ->
              Enum.member?(sender_friends, userid)
            end,
            fn %{userid: userid} ->
              userid
            end
          )

        "contributor" ->
          all_possible_clients
          |> Enum.group_by(
            fn %{userid: userid} ->
              CacheUser.has_any_role?(userid, "Contributor")
            end,
            fn %{userid: userid} ->
              userid
            end
          )

        "dev" ->
          all_possible_clients
          |> Enum.group_by(
            fn %{userid: userid} ->
              CacheUser.has_any_role?(userid, "Core")
            end,
            fn %{userid: userid} ->
              userid
            end
          )

        "admin" ->
          all_possible_clients
          |> Enum.group_by(
            fn %{userid: userid} ->
              CacheUser.has_any_role?(userid, "Admin")
            end,
            fn %{userid: userid} ->
              userid
            end
          )

        "all" ->
          %{
            false: lobby.players ++ state.join_queue
          }

        "default" ->
          %{
            true: [senderid],
            false: List.delete(lobby.players ++ state.join_queue, senderid)
          }
      end

    # Set this lot to be in the queue
    (result[false] || [])
    |> Enum.each(fn userid ->
      Lobby.force_change_client(state.coordinator_id, userid, %{player: false})
    end)

    # And add them to the queue
    new_queue = Enum.shuffle(result[false] || [])

    # Set these lot to be players
    (result[true] || [])
    |> Enum.each(fn userid ->
      Lobby.force_change_client(state.coordinator_id, userid, %{player: true})
    end)

    sender_name = Account.get_username_by_id(senderid)

    ChatLib.say(
      state.coordinator_id,
      "#{sender_name} shuffled the players using mode: #{mode}",
      state.lobby_id
    )

    %{state | join_queue: new_queue}
  end

  #################### Host and Moderator
  def handle_command(%{command: "lock", remaining: remaining, senderid: senderid} = cmd, state) do
    new_locks =
      case get_lock(remaining) do
        nil ->
          Lobby.sayprivateex(
            state.coordinator_id,
            senderid,
            [
              "No lock of that type"
            ],
            state.lobby_id
          )

          state.locks

        lock ->
          ConsulServer.say_command(cmd, state)
          [lock | state.locks] |> Enum.uniq()
      end

    %{state | locks: new_locks}
  end

  def handle_command(%{command: "unlock", remaining: remaining, senderid: senderid} = cmd, state) do
    new_locks =
      case get_lock(remaining) do
        nil ->
          Lobby.sayprivateex(
            state.coordinator_id,
            senderid,
            [
              "No lock of that type"
            ],
            state.lobby_id
          )

          state.locks

        lock ->
          ConsulServer.say_command(cmd, state)
          List.delete(state.locks, lock)
      end

    %{state | locks: new_locks}
  end

  def handle_command(%{command: "specunready"} = cmd, state) do
    battle = Lobby.get_lobby(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Account.get_client_by_id(player_id)

      if client.ready == false and client.player == true do
        CacheUser.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{player: false})
      end
    end)

    ConsulServer.say_command(cmd, state)
  end

  def handle_command(%{command: "set-config-teaser", remaining: new_teaser} = cmd, state) do
    ConsulServer.say_command(cmd, state)
    new_teaser = String.trim(new_teaser)

    new_teaser =
      case chars_valid_for_lobby_name?(new_teaser) do
        true -> new_teaser
        _ -> ""
      end

    Battle.update_lobby_values(state.lobby_id, %{teaser: new_teaser})
    LobbyLib.cast_lobby(state.lobby_id, :refresh_name)
    state
  end

  def handle_command(%{command: "rename", remaining: new_name, senderid: senderid} = cmd, state) do
    new_name = String.trim(new_name)

    stripped_name =
      case chars_valid_for_lobby_name?(new_name) do
        true -> new_name
        _ -> ""
      end

    lobby = Lobby.get_lobby(state.lobby_id)

    {check_name_result, check_name_msg} = LobbyRestrictions.check_lobby_name(stripped_name, state)

    starts_with_lobby_policy =
      new_name
      |> String.downcase()
      |> String.starts_with?("preset")

    cond do
      new_name == "" ->
        Battle.rename_lobby(state.lobby_id, lobby.base_name, nil)
        state

      WordLib.flagged_words(new_name) > 0 ->
        Lobby.sayex(
          state.coordinator_id,
          "That lobby name been rejected. Please be aware that misuse of the lobby naming system can cause your chat privileges to be revoked.",
          state.lobby_id
        )

        state

      state.lobby_policy_id != nil ->
        Lobby.sayex(
          state.coordinator_id,
          "This is a server managed lobby, you cannot rename it",
          state.lobby_id
        )

        state

      # String.length(new_name) > 20 ->
      #   Lobby.sayex(
      #     state.coordinator_id,
      #     "That name (#{new_name}) is too long",
      #     state.lobby_id
      #   )
      #   state

      lobby.lobby_policy_id && starts_with_lobby_policy ->
        Lobby.sayex(
          state.coordinator_id,
          "This is not a server managed lobby, you cannot use that name",
          state.lobby_id
        )

        state

      check_name_result != :ok ->
        Lobby.sayex(
          state.coordinator_id,
          check_name_msg,
          state.lobby_id
        )

        state

      new_name != stripped_name ->
        Lobby.sayex(
          state.coordinator_id,
          "That name contains one or more invalid characters (alphanumeric, spaces and some special characters allowed)",
          state.lobby_id
        )

        state

      senderid != lobby.founder_id ->
        # We have to do this so we don't block the get_state call from the LobbyServer
        # when it tries to query the rating values
        spawn(fn ->
          :timer.sleep(500)
          Battle.rename_lobby(state.lobby_id, new_name, senderid)
        end)

        ConsulServer.say_command(cmd, state)

        if check_name_msg != nil do
          # Send coordinator message which can be long; appears on right
          CacheUser.send_direct_message(state.coordinator_id, senderid, check_name_msg)
        end

        state

      true ->
        Battle.rename_lobby(state.lobby_id, new_name, nil)

        state
    end
  end

  #################### Moderator only
  # ----------------- General commands
  def handle_command(%{command: "makeready", remaining: ""} = cmd, state) do
    battle = Lobby.get_lobby(state.lobby_id)

    battle.players
    |> Enum.each(fn player_id ->
      client = Client.get_client_by_id(player_id)

      if client.ready == false and client.player == true do
        CacheUser.ring(player_id, state.coordinator_id)
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
        CacheUser.ring(player_id, state.coordinator_id)
        Lobby.force_change_client(state.coordinator_id, player_id, %{ready: true})
        ConsulServer.say_command(cmd, state)
    end
  end

  def handle_command(%{command: "success"} = cmd, %{split: nil} = state) do
    ConsulServer.say_command(cmd, state)
    lobby = Lobby.get_lobby(state.lobby_id)

    lobby.players
    |> Enum.map(fn userid -> Client.get_client_by_id(userid) end)
    |> Enum.filter(fn client -> client.player == true end)
    |> Enum.each(fn client ->
      Lobby.say(client.userid, "!y", state.lobby_id)
    end)

    state
  end

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

  def handle_command(%{command: "specafk", senderid: senderid} = cmd, state) do
    lobby = Lobby.get_lobby(state.lobby_id)

    if lobby.in_progress do
      Coordinator.send_to_user(
        senderid,
        "The game is currently in progress, we cannot spec-afk members"
      )
    else
      afk_check_list =
        ConsulServer.list_players(state)
        |> Enum.map(fn %{userid: userid} -> userid end)

      afk_check_list
      |> Enum.each(fn userid ->
        CacheUser.ring(userid, state.coordinator_id)

        CacheUser.send_direct_message(
          state.coordinator_id,
          userid,
          "The lobby you are in is conducting an AFK check, please respond with 'hello' here to show you are not afk or just type something into the lobby chat."
        )
      end)

      ConsulServer.say_command(cmd, %{
        state
        | afk_check_list: afk_check_list,
          afk_check_at: System.system_time(:millisecond)
      })
    end
  end

  def handle_command(%{command: "backofthequeue", remaining: target} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        ConsulServer.say_command(cmd, state)
        new_queue = List.delete(state.join_queue, target_id) ++ [target_id]
        %{state | join_queue: new_queue}
    end
  end

  def handle_command(%{command: "vip", remaining: target, senderid: senderid} = cmd, state) do
    case ConsulServer.get_user(target, state) do
      nil ->
        ConsulServer.say_command(%{cmd | error: "no user found"}, state)

      target_id ->
        ConsulServer.say_command(cmd, state)
        sender_name = CacheUser.get_username(senderid)

        Lobby.sayex(
          state.coordinator_id,
          "#{sender_name} placed #{target} at the front of the join queue",
          state.lobby_id
        )

        %{state | join_queue: Enum.uniq([target_id] ++ state.join_queue)}
    end
  end

  def handle_command(%{command: "pull", remaining: targets} = cmd, state) do
    targets
    |> String.split(" ")
    |> Enum.map(fn name ->
      name
      |> String.trim()
      |> String.downcase()
    end)
    |> Enum.uniq()
    |> Enum.reduce(state, fn target, acc ->
      case ConsulServer.get_user(target, acc) do
        nil ->
          ConsulServer.say_command(%{cmd | error: "user #{target} not found"}, acc)

        target_id ->
          Lobby.force_add_user_to_lobby(target_id, acc.lobby_id)
          ConsulServer.say_command(cmd, acc)
      end
    end)
  end

  def handle_command(%{command: "settag", remaining: remaining} = cmd, state) do
    case String.split(remaining, " ") do
      [key, value | _] ->
        Battle.set_modoption(state.lobby_id, String.downcase(key), value)
        ConsulServer.say_command(cmd, state)

      _ ->
        ConsulServer.say_command(%{cmd | error: "no regex match"}, state)
    end
  end

  def handle_command(%{command: "bstatus", senderid: senderid}, state) do
    balancer_state = Coordinator.call_balancer(state.lobby_id, :report_state)

    values =
      balancer_state
      |> Enum.map(fn {k, v} ->
        "#{k}: #{v}"
      end)
      |> Enum.sort(&<=/2)

    status_msg =
      [
        "#{@splitter} Balancer status #{@splitter}",
        values
      ]
      |> List.flatten()
      |> Enum.filter(fn s -> s != nil end)

    Coordinator.send_to_user(senderid, status_msg)
    state
  end

  def handle_command(%{command: "set", remaining: remaining} = cmd, state) do
    [variable | value_parts] = String.split(remaining, " ")

    balancer_variables = %{
      "max_deviation" => :max_deviation,
      "rating_lower_boundary" => :rating_lower_boundary,
      "rating_upper_boundary" => :rating_upper_boundary,
      "mean_diff_max" => :mean_diff_max,
      "stddev_diff_max" => :stddev_diff_max,
      "fuzz_multiplier" => :fuzz_multiplier
    }

    balancer_key = balancer_variables[variable]

    cond do
      balancer_key != nil ->
        parse_value =
          value_parts
          |> Enum.join(" ")
          |> Integer.parse()

        case parse_value do
          {value, _} ->
            if value >= 0 do
              Coordinator.cast_balancer(state.lobby_id, {:set, balancer_key, value})
              ConsulServer.say_command(cmd, state)
            else
              ConsulServer.say_command(%{cmd | error: "invalid value"}, state)
            end

          _ ->
            ConsulServer.say_command(%{cmd | error: "invalid value"}, state)
        end

      true ->
        ConsulServer.say_command(%{cmd | error: "no variable by that name"}, state)
    end
  end

  def handle_command(%{command: "force_party"}, state) do
    # Forces parties to always be used where possible
    [
      {:max_deviation, 1000},
      {:rating_lower_boundary, 1000},
      {:rating_upper_boundary, 1000},
      {:mean_diff_max, 1000},
      {:stddev_diff_max, 1000}
    ]
    |> Enum.each(fn {key, value} ->
      Coordinator.cast_balancer(state.lobby_id, {:set, key, value})
    end)

    state
  end

  # ----------------- Moderation commands
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
        reason =
          if reason_list == [],
            do: "You have been given a timeout on the naughty step",
            else: Enum.join(reason_list, " ")

        timeout = new_timeout(%{level: :banned, by: cmd.senderid, reason: reason}, state)
        new_timeouts = Map.put(state.timeouts, target_id, timeout)

        Lobby.kick_user_from_battle(target_id, state.lobby_id)
        match_id = Battle.get_lobby_match_id(state.lobby_id)
        Telemetry.log_simple_lobby_event(target_id, match_id, "consul.timeout_command")

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
        match_id = Battle.get_lobby_match_id(state.lobby_id)
        Telemetry.log_simple_lobby_event(target_id, match_id, "consul.lobbykick_command")

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
        match_id = Battle.get_lobby_match_id(state.lobby_id)
        Telemetry.log_simple_lobby_event(target_id, match_id, "consul.lobbyban_command")

        ConsulServer.say_command(cmd, state)

        %{state | bans: new_bans}
        |> ConsulServer.broadcast_update("ban")
    end
  end

  def handle_command(%{command: "lobbybanmult", remaining: targets} = cmd, state) do
    {targets, reason} =
      case String.split(targets, "!!") do
        [t] -> {t, @default_ban_reason}
        [t, r | _] -> {t, String.trim(r)}
      end

    ConsulServer.say_command(cmd, state)
    match_id = Battle.get_lobby_match_id(state.lobby_id)

    String.split(targets, " ")
    |> Enum.reduce(state, fn target, acc ->
      case ConsulServer.get_user(target, acc) do
        nil ->
          acc

        target_id ->
          ban = new_ban(%{level: :banned, by: cmd.senderid, reason: reason}, acc)
          new_bans = Map.put(acc.bans, target_id, ban)
          Lobby.kick_user_from_battle(target_id, acc.lobby_id)
          Telemetry.log_simple_lobby_event(target_id, match_id, "consul.lobbybanmult_command")

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

  def handle_command(%{command: "meme", remaining: meme, senderid: senderid}, state) do
    meme = String.downcase(meme)

    msg = RikerssMemes.handle_meme(meme, senderid, state)

    if not Enum.empty?(msg) do
      Lobby.list_lobby_players!(state.lobby_id)
      |> Enum.each(fn playerid ->
        CacheUser.send_direct_message(state.coordinator_id, playerid, msg)
      end)
    end

    state
  end

  def handle_command(%{command: "reset"} = _cmd, state) do
    ConsulServer.empty_state(state.lobby_id)
    |> ConsulServer.broadcast_update("reset")
  end

  def handle_command(
        %{command: "playerlimit", remaining: value_str, senderid: senderid} = cmd,
        state
      ) do
    case Integer.parse(value_str) do
      {new_limit, _} ->
        ConsulServer.say_command(cmd, state)
        %{state | player_limit: abs(new_limit)}

      _ ->
        ChatLib.sayprivateex(
          state.coordinator_id,
          senderid,
          "Unable to convert #{value_str} into an integer",
          state.lobby_id
        )

        state
    end
  end

  #################### Internal commands
  # Would need to be sent by internal since battlestatus isn't part of the command queue
  def handle_command(
        %{command: "change-battlestatus", remaining: target_id, status: new_status},
        state
      ) do
    Lobby.force_change_client(state.coordinator_id, target_id, new_status)
    state
  end

  def handle_command(%{senderid: senderid} = cmd, state) do
    if Map.has_key?(cmd, :raw) do
      # ChatLib.do_say(cmd.senderid, cmd.raw, state.lobby_id)
      ChatLib.sayprivateex(
        state.coordinator_id,
        senderid,
        "No command of name '#{cmd.command}'",
        state.lobby_id
      )
    else
      Logger.error("No handler in consul_server for command #{Kernel.inspect(cmd)}")
    end

    state
  end

  defp new_ban(data, state) do
    Map.merge(
      %{
        by: state.coordinator_id,
        reason: @default_ban_reason,
        # :player | :spectator | :banned
        level: :banned
      },
      data
    )
  end

  defp new_timeout(data, state) do
    Map.merge(
      %{
        by: state.coordinator_id,
        reason: "You have been given a timeout on the naughty step",
        # :player | :spectator | :banned
        level: :banned
      },
      data
    )
  end

  @spec get_lock(String.t()) :: atom | nil
  defp get_lock(name) do
    case name |> String.downcase() |> String.trim() do
      "team" -> :team
      "allyid" -> :allyid
      "player" -> :player
      "spectator" -> :spectator
      "boss" -> :boss
      _ -> nil
    end
  end

  defp get_queue_position(queue, userid) do
    case Enum.member?(queue, userid) do
      true ->
        Enum.with_index(queue)
        |> Map.new()
        |> Map.get(userid)

      false ->
        -1
    end
  end

  @spec chars_valid_for_lobby_name?(String.t()) :: boolean()
  defp chars_valid_for_lobby_name?(string) do
    case Regex.run(~r/^[a-zA-Z0-9_\-\[\] \<\>\+\|:]+$/, string) do
      [_] -> true
      _ -> false
    end
  end

  @spec get_queue(map()) :: [T.userid()]
  defdelegate get_queue(state), to: ConsulServer
end
