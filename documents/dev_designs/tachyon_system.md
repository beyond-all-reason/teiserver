# tachyon system

This is a high level architecture design of tachyon implementation.

## Goals

* Support up to 100k concurrent users. This is the target we're aiming for steam.
* Support adding and removing nodes to the cluster to adapt to load.
* Support player reconnection. A player that loses connection and reconnect
  within a small window of time shouldn't be impacted: keep its place in any
  matchmaking queue or lobby.
* Support seamless server restart: lobbies, matchmaking queues, chat and so on
  shouldn't be impacted when a server (maybe the only one) restarts.
  This is only for graceful shutdown of nodes. Supporting these features
  for sudden crash is a stretch goal.

Tachyon is a hard requirement for the scaling goal. The other could be done
with existing spring lobby protocol, but supporting tachyon requires significant
changes to existing components so we might as well aim for all of them.

## Player and connection

A player connects to teiserver following the [tachyon doc](https://github.com/beyond-all-reason/tachyon/blob/master/docs/connection.md).

Entities:

* `PlayerConnection`: this is the process handling the http connection then upgraded
  to websocket. It holds the transient state of a player like lobby membership.
* `PlayerSessionSupervisor`: supervisor for `PlayerSession`
* `PlayerSession`: A separate process, unique per player across the cluster.
  Used to track if a given player is actually connected. Shouldn't hold much state.
* `PlayerRegistry`: Global registry for players. Similar to the existing
  `Teiserver.ClientRegistry` in purpose. May be able to reuse that directly.

Example of an interaction where the same player connects, then connects again.

```mermaid

sequenceDiagram
    participant Connection2
    participant Connection
    participant Registry
    participant Session
    participant SessionSupervisor
    Connection ->> Registry: register
    Registry ->> Connection: {:ok, <pid>}

    Connection ->>+ SessionSupervisor: start session
    SessionSupervisor ->> Session: start
    SessionSupervisor ->> -Connection: {:ok, <pid>}
    Session ->> Connection: monitor

    Connection2 ->> Registry: register
    Registry ->> Connection2: {:error, {:already_started, <pid>}}

    Connection2 ->> +Session: update player
    Session ->> Connection2: monitor
    Session ->> Connection: force disconnect + demonitor
    Session ->> -Connection2: :ok

    Connection2 ->> Connection2: disconnect
    Connection2 ->> Session: {:DOWN, _, :process, _, _}
    Session ->> Session: wait until timeout
```

## Autohosts

Autohosts connects to the server and are ready to be summoned to host a game by a lobby.
Maybe expand tachyon so that they can provide some info about themselves, like region, engine version?

Later, we can expand the autohost system to have some form of capacity scheduling.

## Chatrooms
Separate processes dedicated to relay messages across a list of recipients (player or autohost).
Each process has a ring buffer of recent messages to allow replaying messages in case a player
reconnects after crash.


## Lobbies

Process responsible to setup the game and mediating player interactions (except chat).
It should also select a free autohost to launch the game once ready.

Entities:
* Lobby: process that holds:
  * the lobby name and restrictions
  * a list of player with their team membership/spectator
  * a queue of waiting players
  * player statuses like boss
  * votes
  * game settings like map, tweaks and so on.

  Lobbies should keep an internal counter of broadcasted event so that subscribed
  players can detect if they missed one and request the lobby state again.

* LobbyList: manage list of lobbies, holding information for searching and filtering.
  May be in memory process (potentially partitionned) or just saving to the DB.


```mermaid

sequenceDiagram
    participant P1 as Player1
    participant P2 as Player2
    participant Lobby
    participant ChatRoom
    participant LobbyList

    P1 ->> Lobby: subscribe
    P1 ->> +Lobby: create lobby
    Lobby ->> ChatRoom: setup chatroom
    Lobby ->> -P1: {:ok, lobby state}

    P2 ->> Lobby: subscribe
    P2 ->> +Lobby: join lobby
    Lobby ->> -P2: {:ok, lobby state}

    P2 ->> +Lobby: rename
    Lobby ->> -P2: :ok
    Lobby ->> P1: broadcast update
    Lobby ->> P2: broadcast update
    Lobby ->> LobbyList: cast update

```

### Disconnection and leaving a lobby

Lobbies monitor the player session process to check if they are still connected.
When that process dies, the player should be removed from the lobby.




## Matchmaking, player and lobby interactions

Matchmaking can be done using the approach described in [the matchmaking dev guide](./matchmaking.md).
A matchmaking queue is a process, global across the cluster, spawned at startup.
For MVP the queue is a single process, but this could be partitionned by buckets later.
For MVP, the queues will be hardcoded, but that could be DB driven in the future.

Entities:
* P1, P2: PlayerConnections process directly handling tachyon commands.
* MMQueue: one of the matchmaking queue process.
* Lobby: a lobby process. Handle player list, bosses, votes, bosses, game settings like map, ranked?, tweaks.
* Autohost: represent a pool of connected autohost ready to host a game.

```mermaid
sequenceDiagram
    participant P1 as Player1
    participant P2 as Player2
    participant MM as MMQueue
    participant Lobby
    participant Autohost

    P1 ->> MM: join
    P2 ->> MM: join
    MM ->> P1: match found with P2
    MM ->> P2: match found with P1
    P1 ->> MM: accept
    P2 ->> MM: accept
    MM ->> Lobby: create with settings & players
    Lobby ->> MM: {:ok, <lobby_id>}
    Lobby ->> Autohost: request autohost
    Autohost ->> Lobby: :ok
    MM ->> P1: join lobby <lobby_id>
    MM ->> P2: join lobby <lobby_id>
    P1 ->> Lobby: join
    P2 ->> Lobby: join

    Lobby ->> Lobby: make start script
    Lobby ->> Autohost: start game
    Lobby ->> P1: start game
    Lobby ->> P2: start game
```

If a player fail to answer a ready request within a timeout, that player is
evicted from the queue, and all other players are put back where they were.



