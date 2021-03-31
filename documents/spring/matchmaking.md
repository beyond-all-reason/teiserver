Matchmaking is where players join a matchmaking queue and the server gradually matches them up against other players in the same queue. Where possible the server will try to match them up against players of a similar skill but this must be balanced with wait times and queue size.

#### Other resources
- [sring forum thread](https://springrts.com/phpbb/viewtopic.php?f=71&t=33072)
- [ubrserver commit](https://github.com/spring/uberserver/compare/master...gajop:master)

## Client to Server messages
#### `c.mm.list_all_queues`
Expects a response of `s.mm.full_queue_list`

#### `c.mm.list_my_queues`
Expects a response of `s.mm.your_queue_list`

#### `c.mm.get_queue_info queue_name`
Expects a response of `s.mm.queue_info`

#### `c.mm.join_queue queue_name`
Tells the server to add the player to the MM queue. A player can be part of multiple queues at the same time (provided they and their party meet all criteria of the queues such as party size). Expects either a `OK cmd=c.mm.join_queue queue_name` or `NO cmd=c.mm.join_queue queue_name`.

#### `c.mm.leave_queue queue_name`
Tells the server to remove the player from the specified MM queue. No response expected.

#### `c.mm.leave_all_queues`
Tells the server to remove the player from all MM queues. No response selected.

#### `c.mm.ready`
Tells the server the player is ready to participate in the MM game.

#### `c.mm.decline`
Tells the server the player is not ready to participate in the MM game. This will result in the player being removed from all MM queues as if they'd sent `c.mm.leave_all_queues`.

## Server to Client messages
#### `s.mm.full_queue_list`
Lists all the queues currently active along with basic information about each queue such as player count and expected wait time.

#### `s.mm.your_queue_list`
Identical to `s.mm.full_queue_list` but filtered to only include queues the player is a member of.

#### `s.mm.queue_info`
Gives more detailed info about the queue. Currently not sure exactly what info will need to be contained but it feels like this might be needed as things are fleshed out.

#### `s.mm.ready_check queue_name`
When an MM game is ready the player is placed into a special "readyup" state where they are assigned to a potential game and sent this message. The player is expected to either send back a `c.mm.ready` or `c.mm.decline`.

If all players ready up the game is created. If any players fail to ready up in the time frame or decline those players are removed from all matchmaking queues (they can rejoin though a timeout could be applied) and the players that did ready up are placed back in the queue in their previous positions (the readyup state is removed).

## Structure of a queue
- name: String
- team size: Integer
- maps: List(String)
- current_search_time: Integer (seconds)
- current_size: Integer

### Other features to consider
- ZK and FAF have the ability to let you know you'd instant match with someone in a queue. Sort of like a passive search with the ability to make it active and resolve instantly. I think this is a feature that should be added after the main MM situation is sorted as it will be easier to write once the MM system is stabilised.
- Jazzcash: suggestion: 1v1 challenge queue mode. people opt-in to the queue and players at the top of the queue 1v1. losing player goes back to bottom of queue and the next player in the queue plays next. could have a superfluous "winstreak" counter for everybody