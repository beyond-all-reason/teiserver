## The basics
Enabled with `!teiserver` and reverted/halted with `!spads`.

When in Teiserver mode, SPADS will not receive any commands from players, instead they will all be intercepted by Teiserver which will send it's own commands to SPADS.

### How it works
Currently SPADS executes changes to the battle lobby based on commands from players; Teiserver facilities the commands and as such can perform a Man in the middle atttack. When Teiserver mode is engaged it will mean SPADS is given commands by Teiserver which will itself interpret and handle messages; only passing on to SPADS what it wants to. When in Teiserver mode a special Teiserver admin bot will be added to communicate to the host, when disabled the bot will vanish.

### Extra command ideas
- Autocrat boss (bosses are only ones that can start votes)
- Draft mode (captains taking it in turns to pick players for their team)
- Player lock (spectators cannot become players, possibly players that become spectators cannot return to being players)
- Hide spectators (spectator chat hidden, both in lobby and battle)

### Roadmap
#### Stage 1
- Engage and disengage commands
- Votes
- Dictator boss mode
- Map change
- Balance

#### Stage 2
- Player management (kick, force spec etc)
- Autocrat boss mode
- Draft mode

#### Stage 3
- Custom player presets (complete with Web interface/editor even if basic or raw)
- Multiple choice voting
- Player lock

#### Stage 4
- Multiple choice voting

### References
- [SPADS command list](http://planetspads.free.fr/spads/doc/spadsDoc_All.html)
