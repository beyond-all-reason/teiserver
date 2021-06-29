defmodule Teiserver.Coordinator.CoordinatorLib do
  def help() do
    # [] = optional argument, first option is the default
    # () = non optional argument
    """
Commands
TODO: status
    status info about the specific battle

TODO: help
  displays this help text

TODO: blacklist <user> [player | spectator | banned]
  blacklisting someone sets the level they are allowed, if you blacklist to spectator they
  cannot play. If you blacklist to player it's the same as removing the blacklist for that user
  blacklist defaults to banned
  sets the gatekeeper mode to blacklist

whitelist player-as-is
  sets the default whitelist to spectator
  sets the whitelist entry for each player currently on a team to be player
  sets the gatekeeper mode to whitelist
  Useful for soft-locking a battle

whitelist default (player | spectator | banned)
  sets the default whitelist level
  sets the gatekeeper mode to whitelist
    - TODO: Currently will not kick/spec players

TODO: whitelist <user> [player | spectator | banned]
  whitelisting allows the user to that specific role, defaults to player level
  sets the gatekeeper mode to whitelist

welcome-message <message>
  Sets the welcome message sent to anybody joining the lobby

start

forcestart

manual-autohost

reset

change-map

force-spectator

lock-spectator

ban
  kicks a user from the battle lobby, adds them to the blacklist and removes them from the whitelist

kick
  kicks a user from the battle lobby

TODO: gatekeeper (blacklist | whitelist | friends)
  sets the gatekeeper for this battle to whitelist, blacklist or friends method
  at battle lobby open the default is an empty blacklist
  friends currently doesn't work and will allow anybody in

"""

  end
end
