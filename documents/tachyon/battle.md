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
  "battle": {
    "cmd": "c.battle.create",
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
### TODO: `c.battle.start`
### TODO: `c.battle.end`
### TODO: `c.battle.close`

## Interacting
### TODO: `c.battle.join`
### TODO: `c.battle.leave`

## Telemetry
- Mid-battle updates?

