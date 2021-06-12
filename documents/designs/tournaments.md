### Ideas - Core
- Bracket designs
- Tourney types (bracket, round robin etc)
- Ability to connect one tourney to another (e.g. TI group stages -> main event)
- Signup process, might need to be linked to discord
- Track bat
- Admin functionality, maybe something like they temporarily have "friends list" like interactions with all players?
- Challonge API https://api.challonge.com/v1
- Don't allow spectators in tourney games except mods/organisers (as an option)

### Ideas - Extra
- Predicitons
- Ability for people to sign up as standins should people drop out
- Ability to jump to spectate a player's game
- Automatically pull people into their game if ready
- Alerts of when a game should be starting and warnings to admins regarding late starts
- Online checker for specific players

### Extensive ideas from Dubhdara
Wants
- Signup page
- Tourney rules page (specific to the tourney)
- Support for single elimination
- Match scheduling (automatic and manual)
- Score reporting (Challonge API?)
- Async and Synchronous support in terms of player (un)availability
- Tourney page should have indicators of maps and settings for each game played and to-play

### API suggestion from Dubhdara
```
data Competition = Tournament | League # Interface
  teams :: [[Player]]
  matches :: [Match]
  startDate :: UTCTime
  rules :: [String]
}

data Tournament = inherits Competition {
  startTime :: UTCTime
  bracket = Tree Matches
  activePlayers :: Players
}

data League = League inherits Competition {
  roundDurationDays :: Int
  scoreBoard :: [(Player, Int)]
} 

data Player | Player {
  id :: String
  scores :: Map(Tournament, Int)
  availibleTimes :: [(UTCTime, UTCTime)]
}

data Match = Match {
  startTime :: UTCTime
  isScheduled :: Bool
  players :: [Player]
  map :: String
}

CompetetionRunner {
  getNextMatches :: ([Player, Matches]) -> [Matches]
  displayMatches :: [Matches]

TournamentRunner {
  randomizeBrackets :: Tree Matches
  setBrackets :: Tree Matches -> Tree Matches
  displayBrackets :: [Matches]
  setActivePlayers :: [Player] -> ()
}

LeagueRunner  {
  scheduleNextMatch ([Match], [Player]) -> Match
  displayScores ([Player] -> Map(Player, Int)
  advanceRound :: [Player] -> [Player, Match]
}

PlayerAction {
  forfitMatch :: Match -> ()
  reportScore :: (Int, Int, [Player]) -> () # Team1Score, Team2Score, Winners
  signUpForCompetition :: Competition -> ()
  }

AdminAction {
  startCompetition :: Tournament -> ()
  sendAnnoucement :: String -> ()
}
```
