## Showing
### s.lobby.opened
Sent by the server after watching all lobbies via `c.system.watch`.
```json
{
  "cmd": "s.lobby.opened",
  "lobby": lobby
}
```


### s.lobby.closed
Sent by the server after watching all lobbies via `c.system.watch`.
```json
{
  "cmd": "s.lobby.closed",
  "lobby_id": integer
}
```

### c.lobby.query
* query :: Query
* fields :: List (optional)

`fields` lists the additional items to return as part of each lobby. See `c.lobby.get` for more information on which fields can be included. By default the list will be a single item of `lobby`.

#### Queryable fields
- `locked` - Boolean
- `passworded` - Boolean
- `in_progress` - Boolean
- `id_list` - List (Lobby ID)

##### Planned items to add
- `min_player_count` - Integer, a count of the number of players in the lobby
- `max_player_count` - Integer, a count of the number of players in the lobby
- `spectator_count` - Integer, a count of the number of spectators in the lobby
- `member_count` - Integer, a count of the number of players and spectators in the lobby

#### Success response
* lobbies :: List (Battle)

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
  "lobbies": [
    Battle,
    Battle,
    Battle
  ]
}
```


### c.lobby.get
Gets various properties from a lobby based on the command.

Allowed keys:
- lobby
- modoptions
- bots
- players (a list of all player clients)
- member_list (contains a list of all the member clients)

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
### c.lobby.join
Requests to join the lobby, the host will be sent a message asking if the person can join or not. Based on that an accept/reject is sent. If there is a failure to join then it means the host wasn't even consulted as the joiner didn't qualify (e.g. didn't supply the password).
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
  "script_password": "123456789",
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

### `c.lobby.force_join`
Used when the server moves you to a lobby. It will move you out of your existing lobby (if in one) and into the lobby in the message.
```json
{
  "cmd": "s.lobby.join_response",
  "script_password": "123456789",
  "result": "approve",
  "lobby": Lobby,
  "modoptions": [modoptions],
  "bots": [],
  "player_list": [userid],
  "member_list": [userid],
}
```

### c.lobby.leave
No server response.
```json
{
  "cmd": "c.lobby.leave"
}
```

### TODO: c.lobby.send_invite
Sends an invite to a user to them to join the same lobby as yourself. They will still have to go through the same approval process as any other join_lobby command. No response from server.
```json
{
  "cmd": "c.lobby.send_invite",
  "userid": 123,
  "lobby_id": 321,
  "message": "Please come play with me" // Optional?
}
```


### TODO: s.lobby.invite_to_lobby
The message seen by a player being invited to a lobby.
```json
{
  "cmd": "s.lobby.invite_to_lobby",
  "from_userid": 111,
  "lobby_id": 321,
  "message": "Please come play with me" // Optional?,
}
```

### TODO: c.lobby.respond_to_invite
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

### TODO: c.lobby.update_status
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

### s.lobby.update_values
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

### s.lobby.add_user
Sent by the server to inform of a new player joining the lobby.
```json
{
  "cmd": "s.lobby.add_user",
  "lobby_id": lobby_id,
  "joiner_id": user_id,
  "user": User,
  "client": Client
}
```

### TODO: s.lobby.received_lobby_direct_announce
Sent by the server to inform of an announcement made in the room

### s.lobby.updated_queue
Sent by the server when the queue of players waiting to join changes
```json
{
  "cmd": "s.lobby.updated_queue",
  "lobby_id": 650,
  "queue": [4239, 24215, 2183, 25341, 180, 36798, 7102, 14643, 22882]
}
```

## Bots
The responses listed here are the messages which will be sent when any bot is added, updated or removed. The bot commands do not have a success/failure response.

### c.lobby.add_bot
Used to add a bot to the lobby. Once added only the host and owner can alter it.

```json
{
  "cmd": "c.lobby.add_bot",
  "name": "MyAmazingBot",
  "ai_dll": "MyBotDLL",
  "status": {
    "team_colour": "42537",
    "player_number": 8,
    "team_number": 2,
    "side": 1
  }
}

{
  "cmd": "s.lobby.add_bot",
  "bot": {
    "ai_dll": "MyBotDLL",
    "handicap": 0,
    "name": "MyAmazingBot",
    "owner_id": 123,
    "owner_name": "MyNameHere",
    "player": true,
    "player_number": 8,
    "ready": true,
    "side": 1,
    "sync": {"engine": 1, "game": 1, "map": 1},
    "team_colour": "42537",
    "team_number": 2
  }
}
```

### c.lobby.update_bot
```json
{
  "cmd": "c.lobby.update_bot",
  "name": "MyAmazingBot",
  "status": {
    "team_colour": "123445",
    "player_number": 6,
    "team_number": 1,
    "side": 1,
  }
}

{
  "cmd": "s.lobby.update_bot",
  "bot": {
    "ai_dll": "MyBotDLL",
    "handicap": 0,
    "name": "MyAmazingBot",
    "owner_id": 123,
    "owner_name": "MyNameHere",
    "player": true,
    "player_number": 6,
    "ready": true,
    "side": 1,
    "sync": {"engine": 1, "game": 1, "map": 1},
    "team_colour": "123445",
    "team_number": 1
  }
}
```

### c.lobby.remove_bot
```json
{
  "cmd": "c.lobby.remove_bot",
  "name": "MyAmazingBot"
}

{
  "cmd": "s.lobby.remove_bot",
  "bot_name": "BotNumeroUno"
}
```

## TODO: Telemetry
- Mid-battle updates?

