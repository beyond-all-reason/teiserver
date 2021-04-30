## Listing
### `c.battles.list`
* query :: Query

#### Queryable fields
`locked` - Boolean
`started` - Boolean
`player_count` - Integer, a count of the number of players in the battle
`spectator_count` - Integer, a count of the number of spectators in the battle
`user_count` - Integer, a count of the number of players and spectators in the battle
`player_list` - A list of player ids in the battle
`spectator_list` - A list of spectator ids in the battle
`user_list` - A list of player and spectator ids in the battle

#### Response
* battle_list :: List (Battle)

#### Example input/output
```
{
  "cmd": "c.battles.list",
  "query": Query
}

{
  "cmd": "s.battles.list",
  "battle_list": [
    Battle,
    Battle,
    Battle
  ]
}
```

## Creating/Joining
- Create
- Update
- Start
- End
- Close

## Battle contents
- Users joining/leaving
- Players battle-state changing
- Votes/Host commands

## Live
- Mid-battle updates?
