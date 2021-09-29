defmodule Teiserver.Coordinator.CoordinatorLib do
  def help() do
    # [] = optional argument, first option is the default
    # () = non optional argument
    # Anything flagged as TODO is either not implemented or not fully tested
    """
Commands
##### For everybody #####
TODO: status
    status info about the battle lobby

TODO: help
  displays this help text

TODO: splitlobby <message>
  Causes a "vote" to start where other players can elect to join you in splitting the lobby, follow someone
  of their choosing or remain in place. After 20 seconds you are moved to a new (empty) lobby and those that voted yes
  or are following someone that voted yes are also moved to that lobby. Anybody who leaves the original lobby before
  the vote ends will not be moved.

##### Moderator only #####
### General commands
TODO: gatekeeper (default | friends | friendsplay | clan)
  sets the gatekeeper for this battle
    default: no limitations
    TODO: friends allows only friends of existing members to join the lobby
    TODO: friendsplay: allows only friends of existing players to become players (but anybody can join to spectate)
    TODO: clan: allows only members of an existing clan to join the game (enable after one member from each clan is present)

welcome-message <message>
  Sets the welcome message sent to anybody joining the lobby

specunready
  specs all unready players, they are each sent a ring from the coordinator

makeready <user>
  sets a user to ready, when no user is specified all users are set to ready
  any user set to ready is sent a ring from the coordinator

pull <user>
  Pulls a given user into the battle

settag <key> <value>
  Sets a battletag of <key> to <value>

### Moderation
modwarn <user> <hours> <reason>
  Warns the user for that many hours and creates a report for them

modmute <user> <hours> <reason>
  Mutes the user for that many hours and creates a report for them

modban <user> <hours> <reason>
  Bans the user for that many hours and creates a report for them

speclock <user>
  Locks the user into a spectator role. Can be reverted with the unban command.

forceplay <user>
  Forces the user into a player position

lobbyban <user> <reason>
  Bans the user from the lobby but not the server, will refresh on !rehost

lobbybanmult [<user>]
  Bans all users separated by spaces (from the lobby, not the game)

unban <user>
  Removes the user from the lobby banlist

### System
reset
  Resets the coordinator bot for this lobby to the default

##### Internal #####
change-battlestatus
  Changes the battlestatus of a player

$command - Coordinator command
$%command - Don't echo command back to chat
"""
  end
end
