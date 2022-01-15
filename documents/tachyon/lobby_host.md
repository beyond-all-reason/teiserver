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
```
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

### TODO: `s.lobby_host.user_requests_to_join`
### TODO: `c.lobby_host.decline_user_join`
### TODO: `c.lobby_host.allow_user_join`




### TODO: `c.lobby_host.update_status`
### TODO: `s.lobby_host.updated_status`

### TODO: `c.lobby_host.update_host_state`
### TODO: `s.lobby_host.updated_host_state`

### TODO: `c.lobby_host.start`
### TODO: `c.lobby_host.end`
### TODO: `c.lobby_host.close`

