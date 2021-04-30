## Types
Tachyon defines types for all objects wherever possible. Users of the spec are expected to adhere to these types when using it.

## Query
A set of parameters used to filter, sort or limit information from a larger dataset. Typically used when requesting lists of items from the server. The dataset being queried and any additional limits to the query are dictated by the command the query is connected to.

* select :: string
* where :: list(Conditionals)

#### Examples
```
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
```
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
```

## User
* id :: integer
* name :: string
* permissions :: list (string)
* lobby :: string
* bot :: boolean, default: false
* clan_id :: Clan.id

-- Not sure if these need to be included in the object since the client would never need to read them
* friends :: list (User.id)
* friend_requests :: list (User.id)
* ignores :: list (User.id)
* mmr/rank :: map :: (string -> integer)
* icons :: map (string -> integer) # This will be where country flag goes
* ip :: string

#### Examples
```
{
  "id": 1967,
  "name": "Gerald Feinberg"
}
```

## Battle
* id :: integer
* name :: string
* founder_id :: User.id
* type :: string
* max_players :: integer
* passworded :: boolean, default: false
* locked :: boolean, default: false
* engine_name :: string
* engine_version :: string
* players :: list (User.id)
* spectators :: list (User.id)
* bots :: list (User.id)
* ip :: string
* settings :: map :: (string -> string | integer | boolean) -- Replaces spring's scripttags, disabled units and start rectanges should go here I think
* map_hash :: string
* map_name :: string

#### Examples
```
{
  "id": 1967,
  "name": "Battle 1967"
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
```
{
  "id": 1967,
  "name": "Casual 1v1"
}
```


## Success
A string with the word success

#### Examples
```
{
  "result": "success"
}
```

## Failure
A string with the word failure, will always be accompanied by a second field "reason" containing the reason for the failure.

#### Examples
```
{
  "result": "failure",
  "reason": "Reason for failure"
}
```