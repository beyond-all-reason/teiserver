defmodule Teiserver.Coordinator.CoordinatorLib do
  def help() do
    # [] = optional argument, first option is the default
    # () = non optional argument
    # Anything flagged as TODO is either not implemented or not fully tested
    """
Commands
TODO: status
    status info about the battle lobby

TODO: help
  displays this help text

TODO: blacklist <user> [player | spectator | banned]
  blacklisting someone sets the level they are allowed, if you blacklist to spectator they
  cannot play. If you blacklist to player it's the same as removing the blacklist for that user
  blacklist defaults to banned
  sets the gatekeeper mode to blacklist

TODO: whitelist player-as-is
  sets the default whitelist to spectator
  sets the whitelist entry for each player currently on a team to be player
  sets the gatekeeper mode to whitelist
  Useful for soft-locking a battle

TODO: whitelist default (player | spectator | banned)
  sets the default whitelist level
  sets the gatekeeper mode to whitelist
    - TODO: Currently will not kick/spec players

TODO: whitelist <user> [player | spectator | banned]
  whitelisting allows the user to that specific role, defaults to player level
  sets the gatekeeper mode to whitelist

welcome-message <message>
  Sets the welcome message sent to anybody joining the lobby

manual-autohost
  issues a set of commands to SPADS to remove autobalance

TODO: private-game
  issues a set of commands that allow non-friends to join but not to participate

TODO: lock
  locks the battle so only moderators and existing players can join
  does so through the use of the whitelist, setting the default to banned

TODO: unlock
  sets the default whitelist to player, allowing anybody to join and play

reset
  resets the coordinator for this battle to the default state

force-spectator <user>
  sets a given user to be a spectator

lock-spectator
  sets a given user to be a spectator and sets the lists to keep it that way

kick <user>
  kicks a user from the battle lobby

ban <user>
  kicks a user from the battle lobby, adds them to the blacklist and removes them from the whitelist

TODO: temp-ban <user> <time>
  issues a temporary ban for the user in seconds

TODO: unban <user>
  unbans the user, if present in the blacklist also removes them from that
  has no effect on the whitelist

TODO: mute <user>
  mutes a user

TODO: unmute <user>
  unmutes a user

TODO: readyup
  forces all players currently not readied to ready up in the next 5 seconds or be moved to spectators

TODO: bossmode (dictator | autocrat)
  sets the boss mode

TODO: addboss <user>
  adds a player as a boss

TODO: unboss <user>
  removes a player as a boss

TODO: gatekeeper (blacklist | whitelist | friends)
  sets the gatekeeper for this battle to whitelist, blacklist or friends method
  at battle lobby open the default is an empty blacklist
  blacklist stops specific users from taking up specific roles
  whitelist allows only specific users to take up specific roles
  friends allows only friends of existing players to become players (but anybody can join)

<--- Moderator only --->
TODO: makeready <user>
  sets a user to ready

TODO: pull <user>
  Pulls a given user into the battle, it will also remove them from the blacklist and add them to the whitelist
  as a player. If you are not a moderator then this only works on friends.

  Any commands not listed here, if called will passthrough to SPADS as if Coordinator mode wasn't active
  the only exception is a vote requirement may be added to them if you are not able to force them

TODO: settag key value

£!command - Force consul to intercept even when not in active mode
%!command - Don't echo command back to chat
£%!command - Both of the above
"""
  end
end
