## Creation/Management
### `c.lobby_host.create`
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

#### Success response
* battle :: Battle

#### Example input/output
```json
{
  "cmd": "c.lobby_host.create",
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
  "cmd": "s.lobby_host.query",
  "result": "success",
  "battle": Battle
}

{
  "cmd": "s.lobby_host.query",
  "result": "falure",
  "reason": "Permission denied"
}
```

### `c.lobby_host.respond_to_join_request`
The response to a `s.lobby.user_requests_to_join` message informing the server if the request has been accepted or rejected. No server response.
```json
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

### TODO: `c.lobby_host.update_status`
Update the status of a player

### TODO: `s.lobby_host.updated_status`
Tells you a player has had their status updated (by themselves, you or the server)


### TODO: `c.lobby_host.update_host_state`
### TODO: `s.lobby_host.updated_host_state`

### TODO: `c.lobby_host.start`
### TODO: `c.lobby_host.end`
### TODO: `c.lobby_host.close`

