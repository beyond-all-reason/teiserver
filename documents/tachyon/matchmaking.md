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
    "mean_wait_time": 33,
    "member_count": 2
  }
}
```

### TODO: `c.matchmaking.join_queue`
Tells the server to add the player to the MM queue. A player can be part of multiple queues at the same time (provided they and their party meet all criteria of the queues such as party size).

```json
%{
  "cmd": "c.matchmaking.join_queue",
  "queue_id": 123
}
```

### TODO: `c.matchmaking.leave_queue`
Tells the server to remove the player from the specified MM queue. No response expected.

```json
%{
  "cmd": "c.matchmaking.leave_queue",
  "queue_id": 123
}
```

### TODO: `c.matchmaking.leave_all_queues`
Tells the server to remove the player from all MM queues. No response selected.
```json
%{
  "cmd": "c.matchmaking.leave_all_queues"
}
```

### TODO: `s.matchmaking.match_ready`
```json
{
  "cmd": "s.matchmaking.match_ready",
  "match_id": "match-id-string",
  "queue_id": 123
}
```
When a match is made all players are sent this command. They should display an accept/decline dialog to the user and submit the response to the server accordingly.

If all players ready up the game is created. If any players fail to ready up in the time frame or decline those players are removed from all matchmaking queues (they can rejoin though a timeout could be applied) and the players that did ready up are placed back in the queue in their previous positions (the readyup state is removed).

### TODO: `c.matchmaking.accept`
Tells the server the player accepts the match. The match_id needs to be included in the response.
```json
{
  "cmd": "s.matchmaking.match_ready",
  "match_id": "match-id-string"
}
```

### TODO: `c.matchmaking.decline`
Tells the server the player is not ready to participate in the MM game. This will result in the player being removed from all MM queues as if they'd sent `c.matchmaking.leave_all_queues`.

### TODO: `s.matchmaking.match_declined`
Sent when you have either declined the match or have failed to accept within the required timeframe. As part of this you will have been removed from all queues so will need to rejoin them.
```json
{
  "cmd": "s.matchmaking.match_declined",
  "match_id": "match-id-string",
  "queue_id": 123
}
```

### TODO: `s.matchmaking.match_cancelled`
Sent when one or more players have declined or failed to accept in time. You will be re-added to all queues you were in and at the search range you were in when you left.
```json
{
  "cmd": "s.matchmaking.match_cancelled",
  "match_id": "match-id-string",
  "queue_id": 123
}
```


