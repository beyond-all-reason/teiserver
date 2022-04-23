## Auth vs Unauth
The telemetry system is designed to work both with and without being authenticated. If you send commands, send them via the same connection as your normal commands and the server will automatically assign them to a user if it can. If there is no user to attach the information to it will be saved against the hash. The hash can be any printable string value (we advise base64 of a randomly written hash).

## Properties and Events
Properties are values that are stored against the user/hash, when a new value is added it will replace the old value. This is intended for things such as tracking computer specs. Events are tracked against both the user/hash and a timestamp meaning you can log an event multiple times.

Both events and properties are fire and forget in nature, you will not get a server response when sending them.

### `c.telemetry.update_property`
hash: String
property: String
value: String

#### Example input/output
```json
{
  "cmd": "c.telemetry.update_property",
  "hash": "abcdefg",
  "property": "my_property",
  "value": "value"
}
```

### `c.telemetry.log_event`
hash: String
event: String
value: JSON Map

#### Example input/output
```json
{
  "cmd": "c.telemetry.log_event",
  "hash": "abcdefg",
  "event": "my_property",
  "value": {
    "key1": "value",
    "key2": [1,2,3]
  }
}
```
