## Protocol basics
Each request is encoded as JSON compressed with Gzip and then encoded into Base64 to be sent over a TLS connection. This is true for both the server and the client sending messages. A received message will need to be Base64 decoded, uncompressed with Gzip and then parsed into a JSON object. Below is an example of how this would look.

```
{"command":"s.battles.list", "battles": [{"id":1,"name":"Battle 1","players":[1,2,3],"spectators":[11,12,13],"started":false,"locked":false,"tournament":false},{"id":2,"name":"Battle 2","players":[4,5],"spectators":[14,15,16,17,18,19,21],"started":true,"locked":false,"tournament":true}]}

H4sIAAAAAAAAA32OzQ6CMBCE7z4F2fOEZCv4w9HXIBwq1oRYKGmXgyG8uxU4oCYeZ/bLfDtS7dpWdzcqKKRXLWJNSG0ThJDQmqlIypGayDCo062J8GU+JUyg3uqn8ZEqGQr7ChR6U4sWt5QMVuC5F+3FxJ27tsGArKsfmyhu8O/5TtZqwqJV31r1oc2Q/0gzcA4+gI/gE/gMxdsHxA///W9gqqbdC0F8UM4hAQAA
```

## Conventions
All client -> server commands are namespaced with `c` while server to client is always namespaced with `s`. The command or response in question is always located in the mandatory `cmd` field of the json message.

If the client json object contains a `msg_id` field, the server is expected to echo that back inside any json object responses in relation to that command. E.g. if the client requests a list of battles and include a `msg_id`, the battle list response should echo back the same `msg_id`.

## Reading the documentation
Below is the example structure of a command in the documentation.

### `c.command.namespaced.path`
* argument name 1 :: Argument type 1
* argument name 2 :: Argument type 2

#### Extra info
Here will be additional info about the different arguments where necessary. Especially important when there is a query type as these will vary from command to command.

#### Response
A section detailing the possible response(s) from this command. It may be as little as a type or additional information.

#### Examples
```
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
