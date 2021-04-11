Matchmaking is where players join a matchmaking queue and the server gradually matches them up against other players in the same queue. Where possible the server will try to match them up against players of a similar skill but this must be balanced with wait times and queue size.

As per the [new protocol](/documents/new_protocol) work I will be doing all arguments are separated by tabs rather than spaces.

#### Other resources
- [spring forum thread](https://springrts.com/phpbb/viewtopic.php?f=71&t=33072)
- [uberserver commit](https://github.com/spring/uberserver/compare/master...gajop:master)

## Client to Server messages
#### `c.matchmaking.list_all_queues`
Expects a response of `s.matchmaking.full_queue_list`
```
C > c.matchmaking.list_all_queues
S > s.matchmaking.full_queue_list queue1 queue2
```

#### `c.matchmaking.list_my_queues`
Expects a response of `s.matchmaking.your_queue_list`
```
C > c.matchmaking.list_my_queues
S > s.matchmaking.your_queue_list queue1 queue2
```

#### `c.matchmaking.get_queue_info queue_name`
Expects a response of `s.matchmaking.queue_info`
```
C > c.matchmaking.get_queue_info
S > s.matchmaking.queue_info queue1 current_search_time current_size --TODO--
```

#### `c.matchmaking.join_queue queue_name`
Tells the server to add the player to the MM queue. A player can be part of multiple queues at the same time (provided they and their party meet all criteria of the queues such as party size). Expects either a `OK cmd=c.matchmaking.join_queue queue_name` or `NO cmd=c.matchmaking.join_queue queue_name`.
```
C > c.matchmaking.join_queue queue1
S > OK cmd=c.matchmaking.join_queue queue1
S > NO cmd=c.matchmaking.join_queue queue1
```

#### `c.matchmaking.leave_queue queue_name`
```queue_name :: String```
Tells the server to remove the player from the specified MM queue. No response expected.
```
C > c.matchmaking.leave_queue queue1
```

#### `c.matchmaking.leave_all_queues`
Tells the server to remove the player from all MM queues. No response selected.
```
C > c.matchmaking.leave_all_queues
```

#### `c.matchmaking.ready`
Tells the server the player is ready to participate in the MM game. Sent in response to a ready_check. It is possible others will not ready up, in which case a `s.matchmaking.match_cancelled` will be sent.
```
S > s.matchmaking.ready_check queue1
C > c.matchmaking.ready
S > s.matchmaking.match_cancelled queue1
```

#### `c.matchmaking.decline`
Tells the server the player is not ready to participate in the MM game. This will result in the player being removed from all MM queues as if they'd sent `c.matchmaking.leave_all_queues`.
```
S > s.matchmaking.ready_check queue1
C > c.matchmaking.decline
```

## Server to Client messages
#### `s.matchmaking.full_queue_list`
Lists all the queues currently active along with basic information about each queue such as player count and expected wait time.
```
C > c.matchmaking.list_all_queues
S > s.matchmaking.full_queue_list queue1 queue2
```

#### `s.matchmaking.your_queue_list`
Identical to `s.matchmaking.full_queue_list` but filtered to only include queues the player is a member of.
```
C > c.matchmaking.list_my_queues
S > s.matchmaking.your_queue_list queue1 queue2
```

#### `s.matchmaking.queue_info`
Gives more detailed info about the queue. Currently not sure exactly what info will need to be contained but it feels like this might be needed as things are fleshed out.
```
C > c.matchmaking.get_queue_info
S > s.matchmaking.queue_info queue1 current_search_time current_size --TODO--
```

#### `s.matchmaking.ready_check queue_name`
When an MM game is ready the player is placed into a special "readyup" state where they are assigned to a potential game and sent this message. The player is expected to either send back a `c.matchmaking.ready` or `c.matchmaking.decline`.

If all players ready up the game is created. If any players fail to ready up in the time frame or decline those players are removed from all matchmaking queues (they can rejoin though a timeout could be applied) and the players that did ready up are placed back in the queue in their previous positions (the readyup state is removed).
```
S > s.matchmaking.ready_check queue1
C > c.matchmaking.ready
C > c.matchmaking.decline
```

#### `s.matchmaking.match_cancelled queue_name`
When one or more of the other players selected for a match cancel, this message is sent to all others that were selected as potentials for this match. It informs the client they are still in the queue and retain their place in the queue. No client response is expected.
```
S > s.matchmaking.match_cancelled queue1
```

## Structure of a queue on server
**Persistent values**
- `name`: String
- `team_size`: Integer
- `conditions`: Map(String => String) *(e.g. solo, team and ffa ranks, clan only parties, allow partial teams etc)*
- `maps`: List(String) *(Map chosen at random from the list)*
- `settings`: Map(String => String) *(The settings applied to games created by this queue)*

**Transient values**
- `current_search_time`: Integer (seconds)
- `current_size`: Integer
- `contents`: List [PlayerId]

### Other features to consider in the future
- ZK and FAF have the ability to let you know you'd instant match with someone in a queue. Sort of like a passive search with the ability to make it active and resolve instantly. I think this is a feature that should be added after the main MM situation is sorted as it will be easier to write once the MM system is stabilised.
- Jazzcash: suggestion: 1v1 challenge queue mode. people opt-in to the queue and players at the top of the queue 1v1. losing player goes back to bottom of queue and the next player in the queue plays next. could have a superfluous "winstreak" counter for everybody
