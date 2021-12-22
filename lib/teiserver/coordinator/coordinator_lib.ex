defmodule Teiserver.Coordinator.CoordinatorLib do
  alias Teiserver.Data.Types, as: T

  @spec help(T.user(), boolean()) :: String.t()
  def help(user, host) do
    everybody = """
$whoami
Sends back information about who you are

$joinq
Adds you to the queue to join when a space opens up, you will be automatically added to the game as a player. If already a member it has no effect.

$leaveq
Removes you from the join queue.

$status
status info about the battle lobby

$help
displays this help text

$splitlobby
Causes a "vote" to start where other players can elect to join you in splitting the lobby, follow someone
of their choosing or remain in place. After 20 seconds you are moved to a new (empty) lobby and those that voted yes
or are following someone that voted yes are also moved to that lobby.

The following are available to the boss (and battle host)

$welcome-message <message>
Sets the welcome message sent to anybody joining the lobby

$gatekeeper (default | friends | friendsplay | clan)
sets the gatekeeper for this battle
> default: no limitations
> friends allows only friends of existing members to join the lobby
> friendsplay: allows only friends of existing players to become players (but anybody can join to spectate)
> TODO: clan: allows only members of an existing clan to join the game (enable after one member from each clan is present)
"""

    hosts = """
$lock (team | player | spectator | side)
Engages a lock on that mode, when engaged members are unable to change that attribute about themselves.
Hosts and the server are the only thing that will be able to change it. Moderators are typically exempt
from these restrictions.
Multiple locks can be engaged at the same time
> Team: Prevents a member from changing their teamally value (Team 1, 2 etc)
> Allyid: Prevents a member from changing their team value (also called playerid)
> Player: Prevents spectators becoming players
> Spectator: Prevents players becoming spectators
> Side: Prevents players changing their side (faction)

$unlock (team | player | spectator)
Disengages the lock on that mode

$specunready
specs all unready players, they are each sent a ring from the coordinator

$makeready <user>
sets a user to ready, when no user is specified all users are set to ready
any user set to ready is sent a ring from the coordinator

$settag <key> <value>
Sets a battletag of <key> to <value>

$speclock <user>
Locks the user into a spectator role. Can be reverted with the unban command.

$forceplay <user>
Forces the user into a player position

$timeout <user> <reason, default: You have been given a timeout on the naughty step>
Bans the user from the lobby for 1 game, will expire once the game is over

$lobbykick <user>
Kicks the user from the lobby

$lobbyban <user> <reason, default: None given>
Bans the user from the lobby but not the server, will refresh on !rehost

$lobbybanmult [<user>]
Bans all users separated by spaces (from the lobby, not the game)
If you want to add a reason, add a `!!` to the end of the player list, anything after that will be the reason

$unban <user>
Removes the user from the lobby banlist

$forcespec <user>
Moves the user to spectators and bans them from becoming a player

$forceplay <user>
Moves the user to players
"""

    moderators = """
$whois <user>
Sends back information about the user specified

$check <user>
Performs a smurf check against the user mentioned and sends you the result

$pull <user>
Pulls a given user into the battle

$dosplit
Completes the lobby split now

$cancelsplit
Cancels the lobby split

$rename <new name>
Renames the lobby to the name given

$modwarn <user> <hours> <reason>
Warns the user for that many hours and creates a report for them

$modmute <user> <hours> <reason>
Mutes the user for that many hours and creates a report for them

$modban <user> <hours> <reason>
Bans the user for that many hours and creates a report for them

$reset
Resets the coordinator bot for this lobby to the default
"""
    # $command - Coordinator command
    # $%command - Don't echo command back to chat

    [
      everybody,
      (if user.moderator or host, do: hosts, else: ""),
      (if user.moderator, do: moderators, else: "")
    ]
    |> Enum.join("\n")
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
    |> Map.new
  end

  @spec resolve_round(Map.t()) :: {:incomplete | :complete, Map.t()}
  defp resolve_round(split) do
    players = Map.keys(split)

    result = players
    |> Enum.reduce({false, true, split}, fn (player_id, {changes, complete, acc}) ->
      # First find out what their target is, possibly by looking
      # at their target's target
      new_target = case acc[player_id] do
        true -> true
        nil -> nil
        target_id ->
          case split[target_id] do
            true -> true
            nil -> nil
            targets_target -> targets_target
          end
      end
      new_split = Map.put(acc, player_id, new_target)

      # Now, are we still on for completion?
      is_complete = complete and (not is_integer(new_target))

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
      new_v = case v do
        true -> true
        _ -> nil
      end

      {k, new_v}
    end)
  end
end
