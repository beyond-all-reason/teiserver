## Showing
### `c.lobby.query`
* query :: Query

#### Queryable fields
`locked` - Boolean
`in_progress` - Boolean
`player_count` - Integer, a count of the number of players in the battle
`spectator_count` - Integer, a count of the number of spectators in the battle
`user_count` - Integer, a count of the number of players and spectators in the battle
`player_list` - List (User.id), A list of player ids in the battle
`spectator_list` - List (User.id), A list of spectator ids in the battle
`user_list` - List (User.id), A list of player and spectator ids in the battle

#### Success response
* battle_list :: List (Battle)

#### Example input/output
```
{
  "cmd": "c.lobby.query",
  "query": %{
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

## Interacting
### TODO: `c.lobby.join`
Requests to join the battle, the host will be sent a message asking if the person can join or not. Based on that an accept/reject is sent. If there is a failure to join then it means the host wasn't even consulted as the joiner didn't qualify (e.g. didn't supply the password).
```
{
  "cmd": "c.lobby.join",
  "lobby_id": 123,
  "password": "******" // Optional
}

// Stage 1
{
  "cmd": "s.lobby.join",
  "result": "waiting_for_host"
}

{
  "cmd": "s.lobby.join",
  "result": "failure",
  "reason": "Reason for failure"
}

// Stage 2 - sent to the lobby host
// Host approves/rejects the joiner
{
  "cmd": "s.lobby_host.request_to_join",
  "userid": 456
}

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

// Stage 3
// Host response sent to prospective player
{
  "cmd": "s.lobby.join_response",
  "lobbyid": 123,
  "result": "approve",
  "lobby": Lobby
}

{
  "cmd": "s.lobby.join_response",
  "lobbyid": 123,
  "result": "reject",
  "reason": "Reason for rejection"
}
```

### TODO: `c.lobby.force_join`
Used when the server moves you to a lobby. It will move you out of your existing lobby (if in one) and into the lobby in the message
```
{
  "cmd": "s.lobby.join_response",
  "lobby": Lobby,
  "script_password": "123456789"
}
```

### TODO: `c.lobby.leave`
No server response.
```
{
  "cmd": "c.lobby.leave"
}
```

### TODO: `s.lobby.request_to_join`
Sent to the host when someone requests to join the battle. The host should send the server a `c.lobby_host.respond_to_join_request` with their decision.
```
{
  "cmd": "s.lobby.request_to_join",
  "userid": 123
}
```

### TODO: `c.lobby_host.respond_to_join_request`
The response to a `s.lobby.request_to_join` message informing the server if the request has been accepted or rejected. No server response.
```
{
  "cmd": "c.lobby_host.respond_to_join_request",
  "response": "accept",
  "userid": 123
}

{
  "cmd": "c.lobby_host.respond_to_join_request",
  "response": "reject",
  "reason": "reason given",
  "userid": 123
}
```

### TODO: `c.lobby.send_invite`
### TODO: `s.lobby.invite_to_battle`
### TODO: `c.lobby.respond_to_invite`

### TODO: `s.lobby.request_status`
### TODO: `c.lobby.update_status`

### TODO: `c.lobby.updated_client_battlestatus`

### TODO: `s.lobby.user_joined`

### TODO: `s.lobby.received_lobby_direct_announce`

## Telemetry
- Mid-battle updates?

