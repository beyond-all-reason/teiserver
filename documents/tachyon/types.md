## Types
Tachyon defines types for all objects wherever possible. Users of the spec are expected to adhere to these types when using it.


## User
* id :: integer
* name :: string
* bot :: boolean, default: false
* clan_id :: Clan.id, default: nil
* icons :: map (string -> string) -- Badge type as the key, badge icon as the value (e.g. rank => level5)

### Private properties, only sent to the account in question or to special privileged commands
* permissions :: list (string)
* friends :: list (User.id)
* friend_requests :: list (User.id) -- Users requesting this user to be their friend
* ignores :: list (User.id)

#### Examples
```json
{
  "id": 1967,
  "name": "Gerald Feinberg",
  "skill": {
    "1v1": 500,
    "2v2": 634,
  },
  "icons": {
    "time_played": "400",
    "current_season": "bertha",
    "last_season": "korgoth",
  }
}

{
  "id": 1967,
  "name": "Gerald Feinberg",
  "skill": {
    "1v1": 500,
    "2v2": 634,
  },
  "icons": {
    "time_played": "400",
    "current_season": "bertha",
    "last_season": "korgoth",
  },
  "permissions": ["moderator", "beta-tester"],
  "friends": [1,2,3],
  "friend_requests": [4,5,6],
  "ignores": [7,8,9]
}
```

## Client
This represents a user who is logged in. A user who is logged out will not have a client object.
* id :: User.id
* in_game: boolean
* away: boolean

-- Game/Lobby attributes
* ready: boolean
* player_number: integer
* team_number: integer -- I want to rename this and the previous one to make it less confusing
* team_colour: colour
* player: boolean
* bonus: integer, default: 0 -- In spring this is 0-127, here it's an unsigned integer
* sync: map -- key represents the item with a value between 0-1 showing the percentage downloaded
* faction: string
* lobby_id: Lobby.id

-- Other --
* party_id: string
* clan_tag: string
* muted: boolean

#### Examples
```json
{
  "id": 1967,
  "in_game": true,
  "away": false,
  "ready": true,
  "player": true,
  "team_number": 1,
  "team_colour": "#AA9900",
  "sync": {
    "map": 1,
    "engine": 0,
    "game": 1
  },
  "faction": "random",
  "lobby_id": 5,
  "party_id": "abc-def",
  "clan_tag": "TEH",
  "muted": false
}
```

## Lobby
* id :: integer
* name :: string
* founder_id :: User.id
* passworded :: boolean
* locked :: string -- unlocked, friends, whitelist, locked
* engine_name :: string
* engine_version :: string
* players :: list (User.id)
* spectators :: list (User.id)
* bots :: list (User.id)
* ip :: string
* settings :: map :: (string -> any) -- Replaces spring's scripttags, disabled units and should go here I think
* start_areas :: map :: (id -> [type, x1, y1, x2, y2])
* map_name :: string
* map_hash :: string
* public :: boolean

#### Examples
```json
{
  "id": 9556,
  "name": "EU 07 - 670",
  "founder_id": 1967,
  "passworded": false,
  "locked": "unlocked",
  "engine_name": "BAR",
  "engine_version": "145.789-rc3",
  "players": [1,2,3,4],
  "spectators": [5,6,7],
  "bots": [900],
  "ip": "127.0.0.1",
  "settings": {
    "max_players": 16,
    "type": "team",
    "disabled_units": ["unit1", "unit2", "unit3"],
    "start_areas": {
      "1": ["rect", 0, 0, 100, 100],
      "2": ["rect", 300, 300, 400, 400]
    }
  },
  "map_name": "koom valley",
  "map_hash": "hash_string_here",
  "public": true
}
```

## Queue
A queue used in matchmaking

* id :: integer
* name :: string
* team_size :: integer
* conditions :: map (string -> string???)
* settings :: map (string -> any) -- Might not be needed, might be server side only
* map_list :: list (string)

#### Examples
```json
{
  "id": 1967,
  "name": "Competitive 1v1",
  "team_size": 1,
  "conditions": {
    
  },
  "settings": {
    "allow_spectators": false,
    "allow_pauses": false
  },
  "map_list": ["avalanche", "quicksilver"]
}
```

## Party
1 or more players grouped together for the purpose of play and communication.
* id :: String/UUID
* leader :: User.id
* members :: list(User.id)
* invites :: list(User.id) -- A list of users currently being invited to the party

#### Examples
```json
{
  "id": "3cd51300-c8ce-11ec-9db7-f02f74dbae33",
  "leader": 123,
  "members": [123, 456, 789],
  "invites": [222, 444]
}
```

## BlogPost
An item posted to the site blog

* id :: integer
* short_content :: string
* content :: string *The full content of the post*
* url :: string
* tags :: list (string)
* live_from :: timestamp

Still thinking about how to best represent these:
* poster
* category
* comment_count

## BlogComment
A comment attached to a blog post

* content :: string
* commenter :: user
* timestamp :: timestamp

## UserConfigType
Built on top of the Barserver.Config data structures and used in `c.config._user*`

* default :: string
* description :: string
* key :: string
* opts :: map
* section :: string
* type :: boolean
* value_label :: string

#### Examples
```json
  %{
    "default": true,
    "description": "When checked the flag associated with your IP will be displayed. If unchecked your flag will be blank. This will take effect next time you login with your client.",
    "key": "teiserver.Show flag",
    "opts": {},
    "section": "Barserver account",
    "type": "boolean",
    "value_label": "Value"
  }
```

## Error
Returned when an unexpected error is generated. The difference between an error and a failure is the failure is an expected possible outcome (e.g. login failing) while an error is unexpected (e.g. message cannot be decoded). As such the error field will not always have the command being executed (though may sometimes).

#### Examples
```json
{
  "result": "error",
  "error": "base64_decode",
  "location": "decode"
}
```

<!-- ## Query
A set of parameters used to filter, sort or limit information from a larger dataset. Typically used when requesting lists of items from the server. The dataset being queried and any additional limits to the query are dictated by the command the query is connected to.

* select :: string
* where :: list(Conditionals)

#### Examples
```json
{
  "select": [
    "name",
    "players",
    "settings"
  ],
  "where": [
    {"field": "locked"},
    {"field": "started", "value": false},
    {"field": "max_players", "operator": "<=", "value": 8}
  ]
}
```

## Conditional
* field :: string
* operator :: string, default: "="
* value :: any type, default: true

#### Examples
```json
{
  "field": "open"
}

{
  "field": "score",
  "operator": ">",
  "value": 5
}

{
  "field": "id",
  "operator": "in",
  "value": [1,2,3,4]
}

{
  "field": "players",
  "operator": "contains",
  "value": 3
}
``` -->
