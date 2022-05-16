## Protocol basics
Each request is encoded as JSON compressed with Gzip and then encoded into Base64 to be sent over a TLS connection (defaults to port 8202). This is true for both the server and the client sending messages. A received message will need to be Base64 decoded, uncompressed with Gzip and then parsed into a JSON object. Below is an example of how this would look.

```json
// Raw Base64 data
"H4sIAAAAAAAAA4WQyw6CQAxFf8V0fUPSEXyw9DeMi4pjYhwYnCkLQvh3eS1QF+6ak9t7mnZ0FVVnI+Xnjh43yhnkfPG0w3gXFy2oktJSTqcpuGEC1U5aG8YdhsH2Aoq1LVTUz5DBBjxxlaCrLvVNGPsqXVCPWWv+aM2HNkX2I03BGXgH3oMP4CMMrw/Q0Hz5R9IPkcKXpVRDhGKyfCN5NTa01L8Bu8SyUR8BAAA="

// Decoded, Decompressed, Parsed result
{
  "command": "s.lobbies.query",
  "lobbies": [
    {
      "id": 1,
      "name": "Battle 1",
      "players": [1, 2, 3],
      "spectators": [11, 12, 13],
      "started": false,
      "locked": false,
      "tournament": false
    },
    {
      "id": 2,
      "name": "Battle 2",
      "players": [4, 5],
      "spectators": [14, 15, 16, 17, 18, 19, 21],
      "started": true,
      "locked": false,
      "tournament": true
    }
  ]
}
```

## Conventions
All client -> server commands are namespaced with `c` while server to client is always namespaced with `s`. The command or response in question is always located in the mandatory `cmd` field of the json message.

If the client json object contains a `msg_id` field, the server is expected to echo that back inside any json object responses in relation to that command. E.g. if the client requests a list of lobbies and include a `msg_id`, the lobby list response should echo back the same `msg_id`.

## Reading the documentation
Below is the example structure of a command in the documentation.

### `c.command.namespaced.path`
* argument name 1 :: Argument type 1
* argument name 2 :: Argument type 2

#### Extra info
Here will be additional info about the different arguments where necessary. Especially important when there is a query type as these will vary from command to command.

#### Response
A section detailing the possible response(s) from this command. It may be as little as a type or additional information. Some commands may not even have a response.

#### Examples
```json
{
  "cmd": "c.command.namespaced.path",
  "argument name 1": "example value 1",
  "argument name 2": "example value 2",
}


{
  "cmd": "s.command.namespaced.path",
  "data": [
    {
      "key1": "value1a",
      "key2": "value2a"
    },
    {
      "key1": "value1b",
      "key2": "value2b"
    }
  ],
}
```

## Single source of truth
At every stage the central server is considered to be the source of truth; if there is every client to client communication the client should always query the server for information.

## Example and implementations
No lobbies currently implement the protocol, when they do we will add links to them here. In the meantime Teiserver has unit tests for the Tachyon protocol and they can be found at [/test/teiserver/protocols/tachyon](/test/teiserver/protocols/tachyon). The server implementation for Tachyon is found at [/lib/teiserver/protocols/tachyon_v1](/lib/teiserver/protocols/tachyon_v1) though this is not expected to be overly helpful for lobby implementers.

## Spring interop
Given the server is currently used primarily for the Spring protocol we have added the `TACHYON` command to Spring. For testing/interop you can send `TACHYON some_data` where `some_data` is the JSON -> Gzip -> Base64 data you would send via Tachyon normally. It will result in the system sending the result back as if you were using the Tachyon protocol. It will do so without swapping you to the Tachyon protocol; this is intended only to enable access to certain commands added only for Tachyon and not as a long term solution.
