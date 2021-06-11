## Showing
### `c.battle.query`
* query :: Query

#### Queryable fields
`locked` - Boolean
`started` - Boolean
`player_count` - Integer, a count of the number of players in the battle
`spectator_count` - Integer, a count of the number of spectators in the battle
`user_count` - Integer, a count of the number of players and spectators in the battle
`player_list` - List (User.id), A list of player ids in the battle
`spectator_list` - List (User.id), A list of spectator ids in the battle
`user_list` - List (User.id), A list of player and spectator ids in the battle

#### Successful response
* battle_list :: List (Battle)

#### Example input/output
```
{
  "cmd": "c.battle.query",
  "query": Query
}

{
  "cmd": "s.battle.query",
  "battle_list": [
    Battle,
    Battle,
    Battle
  ]
}
```

## Creation/Management
### `c.battle.create`
* battle ::
  * name :: string
  * nattype :: string (none | holepunch | fixed)
  * password :: string, default: nil
  * port :: integer
  * game_hash :: string
  * map_hash :: string
  * map_name :: string
  * game_name :: string
  * engine_name :: string
  * engine_version :: string
  * ip :: string
  * settings :: map

#### Successful response
* battle :: Battle

#### Example input/output
```
{
  "cmd": "c.battle.create",
  "battle": {
    "name": "EU 01 - 123",
    "nattype": "none",
    "password": "password2",
    "port": 1234,
    "game_hash": "string_of_characters",
    "map_hash": "string_of_characters",
    "map_name": "koom valley",
    "game_name": "BAR",
    "engine_name": "spring-105",
    "engine_version": "105.1.2.3",
    "ip": "127.0.0.1",
    "settings": {
      "max_players": 12
    }
  }
}

{
  "cmd": "s.battle.query",
  "result": "success",
  "battle": Battle
}
```

### TODO: `c.battle.update`
### TODO: `s.battle.updated`

### TODO: `c.battle.start`
### TODO: `c.battle.end`
### TODO: `c.battle.close`

## Interacting
### TODO: `c.battle.join`
Requests to join the battle, the host will be sent a message asking if the person can join or not. Based on that an accept/reject is sent. If there is a failure to join then it means the host wasn't even consulted as the joiner didn't qualify (e.g. didn't supply the password).
```
{
  "cmd": "c.battle.join",
  "battle_id": 123,
  "password": "******" // Optional
}

// Stage 1
{
  "cmd": "s.battle.join",
  "result": "waiting_for_host"
}

{
  "cmd": "s.battle.join",
  "result": "failure",
  "reason": "Reason for failure"
}

// Stage 2
// Host approves/rejects the joiner
{
  "cmd": "s.battle.request_to_join",
  "userid": 123
}

{
  "cmd": "c.battle.respond_to_join_request",
  "userid": 123,
  "response": "approve"
}

{
  "cmd": "c.battle.respond_to_join_request",
  "userid": 123,
  "response": "reject",
  "reason": "Reason for rejection"
}

// Stage 3
// Host response sent to prospective player
{
  "cmd": "s.battle.join_response",
  "result": "approve",
  "battle": Battle
}

{
  "cmd": "s.battle.join_response",
  "result": "reject",
  "reason": "Reason for rejection"
}
```

### TODO: `c.battle.leave`
No server response.
```
{
  "cmd": "c.battle.leave"
}

{
  "cmd": "s.battle.leave",
  "result": "success"
}
```

### TODO: `s.battle.request_to_join`
Sent to the host when someone requests to join the battle. The host should send the server a `c.battle.respond_to_join_request` with their decision.
```
{
  "cmd": "s.battle.request_to_join",
  "userid": 123
}
```

### TODO: `c.battle.respond_to_join_request`
The response to a `s.battle.request_to_join` message informing the server if the request has been accepted or rejected. No server response.
```
{
  "cmd": "c.battle.respond_to_join_request",
  "response": "accept",
  "userid": 123
}

{
  "cmd": "c.battle.respond_to_join_request",
  "response": "reject",
  "reason": "reason given",
  "userid": 123
}
```

### TODO: `c.battle.send_invite`
### TODO: `s.battle.invite_to_battle`
### TODO: `c.battle.respond_to_invite`

### TODO: `s.battle.request_status`
### TODO: `c.battle.update_status`

### TODO: `c.battle.message`
### TODO: `s.battle.message`

### TODO: `c.battle.announce` -- Previously sayex
### TODO: `s.battle.announce`

## Telemetry
- Mid-battle updates?

