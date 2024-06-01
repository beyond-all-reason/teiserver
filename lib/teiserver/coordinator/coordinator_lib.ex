defmodule Teiserver.Coordinator.CoordinatorLib do
  alias Teiserver.Data.Types, as: T
  alias Teiserver.CacheUser

  @spec help(T.user(), boolean(), String.t()) :: String.t()
  def help(user, host, command) do
    commands = [
      # ---- Globally useable ----
      {"help", [], "Displays this help text.", :everybody},
      {"whoami", [], "Sends back information about who you are.", :everybody},
      {"whois", ["user"], "Sends back information about the user specified.", :everybody},
      {"discord", [], "Allows linking of your discord account to your BAR account.", :everybody},
      {"mute", ["username"], "Mutes that user and prevents you seeing their messages.",
       :everybody},
      {"unmute", ["username"], "Un-mutes that user and allows you to see their messages.",
       :everybody},
      {"coc", ["term"],
       "Searches the code of conduct and returns items with a textual match in them.",
       :everybody},

      # ---- Only useable in a battle lobby ----
      {"joinq", [],
       "Adds you to the queue to join when a space opens up, you will be automatically added to the game as a player. If already a member it has no effect.",
       :everybody},
      {"leaveq", [], "Removes you from the join queue.", :everybody},
      {"status", [], "Status info about the battle lobby.", :everybody},
      {"afks", [], "Lists possible afk players.", :everybody},
      {"password?", [], "Tells you the room password", :everybody},
      {"splitlobby", ["minimum players"],
       "Causes a \"vote\" to start where other players can elect to join you in splitting the lobby, follow someone
of their choosing or remain in place. After 60 seconds, if at least the minimum number of players agreed to split, you are moved to a new (empty) lobby and those that voted yes
or are following someone that voted yes are also moved to that lobby.", :everybody},
      {"roll", ["range"], "Rolls a random number based on the range format.
- Dice format: nDs, where n is number of dice and s is sides of die. E.g. 4D6 - 4 dice with 6 sides are rolled
- Max format: N, where N is a number and an integer between 1 and N is returned
- Min/Max format: MN MX, where each is a number and an integer between them (inclusive) is returned
", :everybody},
      {"explain", [], "Lists a log of the steps taken to calculate balance for the lobby",
       :everybody},

      # ---- Boss only ----
      {"reset-approval", [],
       "Resets the list of approved players to just the ones present at the moment (approved players are able to join even if it is locked and without needing a password). Requires boss privileges.",
       :everybody},
      {"meme", ["meme"],
       "A predefined bunch of settings for meme games. It's all Rikerss' fault. Requires boss privileges.
- ticks: Ticks only, don't go Cortex!
- nodefence: No defences
- greenfields: No metal extractors
- rich: Infinite money
- poor: No money generation
- hardt1: T1 but no seaplanes or hovers either
- crazy: Random combination of several settings
- undo: Removes all meme effects", :everybody},
      {"welcome-message", ["message"],
       "Sets the welcome message sent to anybody joining the lobby. Run this command without a message to clear the existing message. Requires boss privileges. Use $$ to add a line return.",
       :everybody},
      {"gatekeeper", ["(default | friends | friendsplay | clan)"],
       "sets the gatekeeper for this battle. Requires boss privileges.
> default: no limitations
> friends allows only friends of existing members to join the lobby
> friendsplay: allows only friends of existing players to become players (but anybody can join to spectate)",
       :everybody},
      {"rename", ["new name"], "Renames the lobby to the name given. Requires boss privileges.",
       :everybody},
      {"minratinglevel", ["min-level"],
       "Sets the minimum level for players, you must be at least this rating to be a player. Requires boss privileges.",
       :everybody},
      {"maxratinglevel", ["max-level"],
       "Sets the maximum level for players, you must be at below this rating to be a player. Requires boss privileges.",
       :everybody},
      {"setratinglevels", ["min-level", "max-level"],
       "Sets the minimum and maximum rating levels for players. Requires boss privileges.",
       :everybody},
       {"resetratinglevels", [],
       "Resets the rating level limits to not exist. Requires boss privileges.",
       :everybody},
      {"minchevlevel", ["min-level"],
       "Sets the minimum chevron level for players. Requires boss privileges. Leave number blank to reset it.",
       :everybody},
      {"maxchevlevel", ["max-level"],
      "Sets the maximum chevron level for players. Requires boss privileges. Leave number blank to reset it.",
       :everybody},
       {"resetchevlevels", [],
       "Resets the chevron level restrictions to not exist. Requires boss privileges.",
       :everybody},
      # {"resetranklevels", [], "Resets the rank level limits to not exist. Player limiting commands are designed to be used with $rename, please be careful not to abuse them. Requires boss privileges.", :everybody},
      # {"minranklevel", ["min-level"], "Sets the minimum rank level for players, you must be at least this rank to be a player. Requires boss privileges.", :everybody},
      # {"maxranklevel", ["max-level"], "Sets the maximum rank level for players, you must be at below this rank to be a player. Requires boss privileges.", :everybody},
      # {"setranklevels", ["min-level", "max-level"], "Sets the minimum and maximum rank levels for players. Requires boss privileges.", :everybody},

      # ---- "hosts" only ----
      {"lock", ["(team | player | spectator | side)"],
       "Engages a lock on that mode, when engaged members are unable to change that attribute about themselves.
hosts and the server are the only thing that will be able to change it. Moderators are typically exempt
from these restrictions.
Multiple locks can be engaged at the same time
> Team: Prevents a member from changing their teamally value (Team 1, 2 etc)
> Allyid: Prevents a member from changing their team value (also called playerid)
> Player: Prevents spectators becoming players
> Spectator: Prevents players becoming spectators
> Boss: Prevents unbossing except by moderators and bosses", :host},
      {"unlock", ["(team | player | spectator)"], "Disengages the lock on that mode", :host},
      {"specunready", [],
       "Specs all unready players, they are each sent a ring from the coordinator.", :host},
      {"makeready", ["user"],
       "Sets a user to ready, when no user is specified all users are set to ready
  any user set to ready is sent a ring from the coordinator", :host},
      {"settag", ["key", "value"], "Sets a battletag of <key> to <value>", :host},
      {"speclock", ["user"],
       "Locks the user into a spectator role. Can be reverted with the unban command.", :host},
      {"forceplay", ["user"], "Forces the user into a player position.", :host},
      {"timeout", ["user", "reason, default: You have been given a timeout on the naughty step"],
       "Bans the user from the lobby for 1 game, will expire once the game is over.", :host},
      {"lobbykick ", ["user"], "Kicks the user from the lobby.", :host},
      {"lobbyban", ["user", "reason , default: None given"],
       "Bans the user from the lobby but not the server, will refresh on !rehost", :host},
      {"lobbybanmult", ["user"],
       "Bans all users separated by spaces (from the lobby, not the game)
  If you want to add a reason, add a `!!` to the end of the player list, anything after that will be the reason.",
       :host},
      {"unban", ["user"], "Removes the user from the lobby banlist.", :host},
      {"forcespec", ["user"],
       "Moves the user to spectators and bans them from becoming a player.", :host},

      # ---- :moderators only ----
      {"success", [],
       "Sends a \"!y\" message from every player to the game host to make a vote pass.",
       :moderator},
      {"playerlimit", ["limit"], "Sets a new player limit for this specific host.", :moderator},
      {"check", ["user"],
       "Performs a smurf check against the user mentioned and sends you the result.", :moderator},
      {"pull", ["user"], "Pulls a given user into the battle.", :moderator},
      {"dosplit", [], "Completes the lobby split now.", :moderator},
      {"cancelsplit", [], "Cancels the lobby split.", :moderator},
      {"vip", ["name"],
       "Places that user at the front of the queue. This command will always output it's use even if used with the % operator.",
       :moderator},
      {"reset", [], "Resets the coordinator bot for this lobby to the default.", :moderator},
      {"specafk", [],
       "Everybody is sent a message asking them to confirm they are not afk. If they don't respond within 40 seconds they are moved to spectators. Requires boss privileges.",
       :moderator}
    ]

    # $command - Coordinator command
    # $%command - Don't echo command back to chat
    result =
      commands
      |> Enum.filter(fn {cmd, _args, _desc, group} ->
        (cmd == command or command == "") and can_use?(user, host, group)
      end)

    case result do
      [{cmd, args, desc, _group}] ->
        arg_str = args |> Enum.map(fn a -> " <#{a}>" end)
        "$#{cmd}#{arg_str}\n#{desc}"

      _ ->
        if command != "" do
          "No commands matching that filter."
        else
          result
          |> Enum.map(fn {cmd, args, desc, _group} ->
            arg_str = args |> Enum.map(fn a -> " <#{a}>" end)
            "\n$#{cmd}#{arg_str}\n#{desc}\n"
          end)
          |> List.to_string()
        end
    end
  end

  @doc """
  We call resolve_split to resolve the overall list of splits (y/n/follow). The issue
  comes when we have multiple layers of people following each other. For this we recursively
  call resolve_round.

  When resolve_round finds circular references it drops them and they don't go anywhere.
  """
  @spec resolve_split(Map.t()) :: Map.t()
  def resolve_split(split) do
    case resolve_round(split) do
      {:complete, result} -> result
      {:incomplete, result} -> resolve_split(result)
    end
    |> Enum.filter(fn {_k, v} -> v end)
    |> Map.new()
  end

  @spec resolve_round(Map.t()) :: {:incomplete | :complete, Map.t()}
  defp resolve_round(split) do
    players = Map.keys(split)

    result =
      players
      |> Enum.reduce({false, true, split}, fn player_id, {changes, complete, acc} ->
        # First find out what their target is, possibly by looking
        # at their target's target
        new_target =
          case acc[player_id] do
            true ->
              true

            nil ->
              nil

            target_id ->
              case split[target_id] do
                true -> true
                nil -> nil
                targets_target -> targets_target
              end
          end

        new_split = Map.put(acc, player_id, new_target)

        # Now, are we still on for completion?
        is_complete = complete and not is_integer(new_target)

        if new_target == split[player_id] do
          {changes, is_complete, new_split}
        else
          {true, is_complete, new_split}
        end
      end)

    case result do
      {false, true, split} -> {:complete, split}
      {false, false, split} -> {:complete, remove_circular(split)}
      {true, _, split} -> {:incomplete, split}
    end
  end

  @spec remove_circular(Map.t()) :: Map.t()
  defp remove_circular(split) do
    split
    |> Map.new(fn {k, v} ->
      new_v =
        case v do
          true -> true
          _ -> nil
        end

      {k, new_v}
    end)
  end

  @spec can_use?(T.user(), boolean(), atom) :: boolean()
  defp can_use?(user, host, group) do
    case group do
      :everybody -> true
      :host -> CacheUser.is_moderator?(user) or host
      :moderator -> CacheUser.is_moderator?(user)
      _ -> false
    end
  end
end
