## Client initiated
### `c.system.ping`
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

## Server initiated
#### `s.system.server_event`
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
