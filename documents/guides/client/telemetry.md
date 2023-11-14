# Entry types
Client telemetry events take four main forms: Properties, Simple Events, Complex Events and Live Events.

## Properties
Properties are for tracking the latest value of a given key. If a new property is set it will overwrite the last one. This is for things like settings/configuration (e.g. fullscreen vs borderless, grid-keys vs legacy).

Note we also track properties for anon users but create a unique hash so as to help prevent duplication of the data. This hash should be created on install and not contain personal information of any sort. A user uninstalling and reinstalling should generate a new hash value.

Example property message structure:
```
c.telemetry.update_client_property property_name value user_hash
```

Example property message contents:
```
c.telemetry.update_client_property property_name e30= TXlWYWx1ZUdvZXNoZXJl
```

Example database representation:
```json
{
  "property_type": "window-mode",
  "user_hash": "MyValueGoeshere",// Anon users have this and no user_id
  "user_id": 123,// Auth'd users have this and no user_hash
  "value": "fullscreen"
}
```

## Simple events
Simple events note what happened and that's it. On the server there are two integer values linking the user and event type to the relevant lookups and a timestamp. They've very small and intended to be used frequently.

Example simple client event message:
```
c.telemetry.simple_client_event joined_match
```

Example database representation:
```json
{
  "event_type": "joined_match",
  "user_id": 123,
  "timestamp": 2023-11-13 12:34:56
}
```

## Complex events
Complex events also add additional data in the form of a JSON blob. They take up more space and are intended to be used less frequently.

Example complex client event message:
```
c.telemetry.complex_client_event joined_match eyJmYWN0aW9uIjogImZhY3Rpb24xIiwic3RhcnRfbG9jYXRpb24iOiBbMTIzLCA0NTZdfQ==
```

Example database representation:
```json
{
  "event_type": "joined_match",
  "user_id": 123,
  "data": {
    "faction": "faction1",
    "start_location": [123, 456]
  },
  "timestamp": 2023-11-13 12:34:56
}
```

## Live events
Live events are not persisted, they are for events currently taking place (e.g. in a match though can be outside of a match too).

Example live match event message:
```
c.telemetry.live_match_event resource_production eyIxIjogeyJtZXRhbCI6IDEyMywiZW5lcmd5IjogNDU2N30sIjIiOnsibWV0YWwiOjIzNCwiZW5lcmd5Ijo3ODkwfX0=
```

Example server representation of live event:
```json
{
  "event_type": "resource_production",
  "user_id": 123,
  "lobby_id": 456,
  "match_id": 789,
  "data": {
    "1": {
      "metal": 123,
      "energy": 4567
    },
    "2": {
      "metal": 234,
      "energy": 7890
    }
  },
  "timestamp": 2023-11-13 12:34:56
}
```

## Infologs
Structure
```
c.telemetry.upload_infolog log_type user_hash metadata contents
```

Example
```
c.telemetry.upload_infolog log_type user_hash e30= VGhpcyBpcyBteSBpbmZvbG9nIHRleHQKTGluZSAyCkxpbmUgMwpNb3JlIHN0dWZmIGhlcmU=
```
