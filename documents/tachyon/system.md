## Client initiated
### `c.system.ping`
No arguments

#### Success response
No response data

#### Example input/output
```
{
  "cmd": "c.system.ping"
}

{
  "cmd": "s.system.pong"
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
```
{
  "cmd": "c.system.server_event",
  "event": "server_restart"
}
```
