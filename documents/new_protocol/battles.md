## Listing
### `c.battles.list [query]`
Expects a response of `s.battles.list_ids` or multiple `s.battles.detail` depending on the query arguments.

#### Fields
`locked` - Boolean
`started` - Boolean
`players` - Integer, a count of the number of players in the battle
`spectators` - Integer, a count of the number of spectators in the battle
`users` - Integer, a count of the number of players and spectators in the battle

#### Additional query options
`select` - Field list, if not used or set to just `ids` then the server will respond with a `list_ids`, otherwise a list of `detail`.

#### Example input/output
```
C > c.battles.list started = false  locked = false  players > 5
S > s.battles.list_ids 1  2  3

C > c.battles.list select = id, name, players  started = false  locked = false  players > 5
S > s.battles.list_detail 1  battle1  5
S > s.battles.list_detail 2  battle2  3
S > s.battles.list_detail 3  battle3  0
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
