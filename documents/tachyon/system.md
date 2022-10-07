## Client initiated
### c.system.ping
No arguments

#### Success response
Responds with a pong and the system time. This time can be used to calculate offsets between the local time and server time.

#### Example input/output
```json
{
  "cmd": "c.system.ping"
}

{
  "cmd": "s.system.pong",
  "time": 123456789
}
```

### c.system.watch
Subscribes you to updates updates for a given pubsub channel.

```json
{
  "cmd": "c.lobby.watch",
  "channel": channel_name
}

{
  "cmd": "s.lobby.watch",
  "result": "success",
  "lobby_id": 123
}

{
  "cmd": "s.lobby.watch",
  "result": "failure",
  "reason": "No lobby",
  "lobby_id": 1234
}
```

#### Possible channel names:
**`server_stats`**
Every 9-10 seconds you will be sent a list of some server stats showing the current state of the server.
```json
{
  "cmd": "s.server.server_stats",
  "data": {
    "user_count": 10,
    "player_count": 6,
    "lobby_count": 4,
    "in_progress_lobby_count": 2
  }
}
```

**`all_lobbies`**
Subscribes you to global lobby updates such as lobbies opening, closing and updating.

**`lobby:<LOBBY_ID>`**
Subscribes you to lobby updates for a given lobby without joining it. Does not subscribe you to the lobby chat and if you join then leave a lobby you will need to resubscribe to it.

**`friends`**
Subscribes you to information about each of your friends at the time of calling. If you add/remove a friend this will not updated an you will need to watch/unwatch using `friend:<USERID>`


### c.system.unwatch
Unsubscribes you to the lobby updates for that particular lobby. Note if you are a member of a lobby it is inadvisable to call this for that lobby.
```json
{
  "cmd": "c.lobby.unwatch",
  "lobby_id": 123
}

{
  "cmd": "s.lobby.unwatch",
  "result": "success",
  "lobby_id": 123
}
```

## Server initiated
#### s.system.server_event
Instructs the application of an event taking place on the server.

#### Arguments
event :: "server_restart"

#### Event types
**server_restart** - Indicates the server is in the process of or about to restart. This means it will not respond to commands or send updated data until the restart has taken place.

#### Examples
```json
{
  "cmd": "c.system.server_event",
  "event": "server_restart"
}
```
