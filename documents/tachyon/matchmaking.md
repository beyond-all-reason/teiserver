## Showing
### `c.matchmaking.query`
* query :: Query

#### Queryable fields
-- None yet

#### Success response
* queue_list :: List (Queue)

#### Example input/output
```json
{
  "cmd": "c.matchmaking.query",
  "query": Query
}

{
  "cmd": "s.matchmaking.query",
  "matchmaking_list": [
    Queue,
    Queue,
    Queue
  ]
}
```

### TODO: `c.matchmaking.list_my_queues`
Operates the same way as the queue query but with a preset set of filters, only returning queues you are currently a part of.

### `c.matchmaking.get_queue_info`
### Result
* wait_time: The amount of time most players are waiting for a game (in seconds), exact method of calculation may vary
* player_count: The number of players currently in the queue

#### Example input/output
```json
{
  "cmd": "c.matchmaking.get_queue_info",
  "queue_id": 123
}

{
  "cmd": "s.matchmaking.queue_info",
  "queue": {
    "queue_id": 123,
    "name": "Best queue name in the world",
    "last_wait_time": 33,
    "player_count": 2
  }
}
```


### TODO: `c.matchmaking.join_queue`
Tells the server to add the player to the MM queue. A player can be part of multiple queues at the same time (provided they and their party meet all criteria of the queues such as party size).

### TODO: `c.matchmaking.leave_queue`
Tells the server to remove the player from the specified MM queue. No response expected.

### TODO: `c.matchmaking.leave_all_queues`
Tells the server to remove the player from all MM queues. No response selected.

### TODO: `s.matchmaking.ready_check`
When an MM game is ready the player is placed into a special "readyup" state where they are assigned to a potential game and sent this message. The player is expected to either send back a `c.matchmaking.ready` or `c.matchmaking.decline`.

If all players ready up the game is created. If any players fail to ready up in the time frame or decline those players are removed from all matchmaking queues (they can rejoin though a timeout could be applied) and the players that did ready up are placed back in the queue in their previous positions (the readyup state is removed).

### TODO: `c.matchmaking.ready`
Tells the server the player is ready to participate in the MM game. Sent in response to a ready_check.

### TODO: `c.matchmaking.decline`
Tells the server the player is not ready to participate in the MM game. This will result in the player being removed from all MM queues as if they'd sent `c.matchmaking.leave_all_queues`.

### TODO: `s.matchmaking.match_cancelled`
When one or more of the other players selected for a match cancel, this message is sent to all others that were selected as potentials for this match. It informs the client they are still in the queue and retain their place in the queue. No client response is expected.

### TODO: `s.matchmaking.removed_from_queue`

