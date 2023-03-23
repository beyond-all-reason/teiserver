## Protocol basics
[Tachyon](https://github.com/beyond-all-reason/tachyon) uses JSON sent over a Websocket transport layer. This document defines how the protocol is used with the server and any server-specific details. For protocol related information please see the [repo](https://github.com/beyond-all-reason/tachyon).

## Authentication
Authentication happens at the point of connection. You must first get a token for the user, this is done with a POST request to the token request endpoint `/teiserver/api/request_token`. Your post body must include both `email` and `password` to authenticate your request.

If successful you will receive a response such as:
```json
{
  "result": "success",
  "token_value": "token-value-goes-here"
}
```

Failures will take the form:
```json
{
  "result": "failure",
  "reason": "Invalid credentials"
}
```

## Basic structure
Messages are expected to have this approximate structure:
```json
{
  "command": "command/goes/here",
  "data": {
    "key": "value"
  }
}
```

Responses will be of a similar format as defined in the JSON schema held in the [Tachyon repo](https://github.com/beyond-all-reason/tachyon).


## Updating schema file
```bash
curl -o priv/tachyon/v1.json https://raw.githubusercontent.com/beyond-all-reason/tachyon/master/schema.json
```

6:46