## The basics
Enabled with `!coordinator start` and reverted/halted with `!coordinator stop`.

When in Coordinator mode, SPADS will not receive any commands from players, instead they will all be intercepted by Teiserver which will send it's own commands to SPADS or in some cases allow a passthrough.

## How it works
Currently SPADS executes changes to the battle lobby based on commands from players; Teiserver facilities the commands and as such can perform a Man in the middle interception. When Coordinator mode is engaged it will mean SPADS is given commands by Teiserver which will itself interpret and handle messages; only passing on to SPADS what it wants to.

## Coordinator bot
The coordinator bot is run directly by the server and will be present in the `#coordinator` channel. It will respond to messages by saying it doesn't respond to them; I am expecting to add functionality in this area.

### Boss modes
- Dictator: Only bosses can vote (not implemented)
- Autocrat: Everybody can vote but only bosses can start them (not implemented)

### Extra command ideas
- Draft mode (captains taking it in turns to pick players for their team)
- Player lock (spectators cannot become players, possibly players that become spectators cannot return to being players)
- Hide spectators (spectator chat hidden, both in lobby and battle)
- Readyup: forces all players to be ready or be force-specced
- Multiple choice voting

### References
- [SPADS command list](http://planetspads.free.fr/spads/doc/spadsDoc_All.html)
