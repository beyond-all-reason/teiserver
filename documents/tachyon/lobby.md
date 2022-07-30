## Showing
### `c.lobby.query`
* query :: Query
* fields :: List (optional)

`fields` lists the additional items to return as part of each lobby. See `c.lobby.get` for more information on which fields can be included. By default the list will be a single item of `lobby`.

#### Queryable fields
- `locked` - Boolean
- `passworded` - Boolean
- `in_progress` - Boolean
- `id_list` - List (Lobby ID)

##### Planned items to add
- `min_player_count` - Integer, a count of the number of players in the battle
- `max_player_count` - Integer, a count of the number of players in the battle
- `spectator_count` - Integer, a count of the number of spectators in the battle
- `member_count` - Integer, a count of the number of players and spectators in the battle

#### Success response
* battle_list :: List (Battle)

#### Example input/output
```json
{
  "cmd": "c.lobby.query",
  "fields": [],
  "query": {
    "locked": false
  }
}

{
  "cmd": "s.lobby.query",
  "battle_list": [
    Battle,
    Battle,
    Battle
  ]
}
```

### `c.lobby.watch`
Subscribes you to lobby updates for a given lobby without joining it. Does not subscribe you to the lobby chat and if you join then leave a lobby you will need to resubscribe to it.
```json
{
  "cmd": "c.lobby.watch",
  "lobby_id": 123
}

{
  "cmd": "s.lobby.watch",
  "result": "success",
  "lobby_id": 123
}

{
  "cmd": "s.lobby.watch",
  "result": "failure",
  "reason": "No lobby",
  "lobby_id": 1234
}
```

### `c.lobby.get`
Gets various properties from a lobby based on the command.

Allowed keys:
- lobby
- modoptions
- bots
- players
- members (contains all members, not just players)

```json
{
  "cmd": "c.lobby.get",
  "lobby_id": 123,
  "keys": ["lobby", "modoptions", "bots"]
}

{
  "cmd": "s.lobby.get",
  "lobby_id": 123,
  "lobby": {},
  "bots": {},
  "modoptions": {},
}
```

## Interacting
### `c.lobby.join`
Requests to join the battle, the host will be sent a message asking if the person can join or not. Based on that an accept/reject is sent. If there is a failure to join then it means the host wasn't even consulted as the joiner didn't qualify (e.g. didn't supply the password).
**Stage 1**
```json
{
  "cmd": "c.lobby.join",
  "lobby_id": 123,
  "password": "******" // Optional
}

// Response
{
  "cmd": "s.lobby.join",
  "result": "waiting_for_host"
}

{
  "cmd": "s.lobby.join",
  "result": "failure",
  "reason": "Reason for failure"
}
```

**Stage 2** - sent to the lobby host
```json
// Host approves/rejects the joiner
// this is what the lobby host sees
{
  "cmd": "s.lobby_host.request_to_join",
  "userid": 456
}

// This is how the lobby host replies to the server
{
  "cmd": "c.lobby_host.respond_to_join_request",
  "userid": 456,
  "response": "approve"
}

{
  "cmd": "c.lobby_host.respond_to_join_request",
  "userid": 456,
  "response": "reject",
  "reason": "Reason for rejection"
}
```

**Stage 3**
```json
// Server sends the response to the would-be player
// Approval
{
  "cmd": "s.lobby.join_response",
  "lobbyid": 123,
  "result": "approve",
  "lobby": Lobby,
  "modoptions": [modoptions],
  "bots": [],
  "player_list": [userid],
  "member_list": [userid],
}

// Rejection
{
  "cmd": "s.lobby.join_response",
  "lobbyid": 123,
  "result": "reject",
  "reason": "Reason for rejection"
}
```

### TODO: `c.lobby.force_join`
Used when the server moves you to a lobby. It will move you out of your existing lobby (if in one) and into the lobby in the message
```json
{
  "cmd": "s.lobby.join_response",
  "lobby": Lobby,
  "script_password": "123456789"
}
```

### `c.lobby.leave`
No server response.
```json
{
  "cmd": "c.lobby.leave"
}
```

### TODO: `c.lobby.send_invite`
Sends an invite to a user to them to join the same battle as yourself. They will still have to go through the same approval process as any other join_battle command. No response from server.
```json
{
  "cmd": "c.lobby.send_invite",
  "userid": 123,
  "lobby_id": 321,
  "message": "Please come play with me" // Optional?
}
```


### TODO: `s.lobby.invite_to_battle`
The message seen by a player being invited to a battle.
```json
{
  "cmd": "s.lobby.invite_to_battle",
  "from_userid": 111,
  "lobby_id": 321,
  "message": "Please come play with me" // Optional?,
}
```

### TODO: `c.lobby.respond_to_invite`
Respond to an invite. This is equivalent to sending the join_lobby command listed above, the key difference it will circumvent certain locks (e.g. passwords).
```json
{
  "cmd": "c.lobby.respond_to_invite",
  "lobby_id": 321,
  "accept": true,
}

{
  "cmd": "c.lobby.respond_to_invite",
  "lobby_id": 321,
  "accept": false,
}
```

### TODO: `c.lobby.update_status`
Sent by a client to inform the server their status is updated. Below are the fields you can update as part of the `client` object you send with the message:

* `status`: String -- one of: ready, unready, afk, in-game
* `player_id`: integer -- In spring this would be `team_number`
* `team_id`: integer -- In spring this would be `ally_team_number`
* `team_color`: colour
* `player`: boolean
* `sync`: list(String) -- A list of things not yet sync'd, e.g. map, engine
* `faction`: string

```json
{
  "cmd": "c.lobby.update_status",
  "client": {
    "status": "ready",
    "player_id": 3,
    "team_id": 1,
    "team_color": "#AA55AA",
    "player": true,
    "sync": ["map", "game"],
    "faction": "cortex"
  }
}
```

### `s.lobby.update_values`
Sent by the server to inform of a change in one or more lobby_data values.
```json
{
  "cmd": "c.lobby.update_values",
  "lobby_id": 123,
  "new_values": {
    "map_name": "Not DSDR"
  }
}

```


### TODO: `s.lobby.user_joined`
Sent by the server to inform of a new player joining the battle room.
```

```

### TODO: `s.lobby.received_lobby_direct_announce`
Sent by the server to inform of an announcement made in the room

## TODO: Bot stuff
- Add/Remove/Update

## TODO: Telemetry
- Mid-battle updates?

