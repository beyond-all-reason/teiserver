### TODO: `c.communication.join_room`
* room_name :: string

#### Success response
* result :: "success"

#### Failure response
* result :: "failure"
* reason :: string

#### Example input/output
```json
{
  "cmd": "c.communication.join_room",
  "room_name": "main"
}

{
  "cmd": "s.communication.join_room",
  "result": "success"
}


{
  "cmd": "c.communication.join_room",
  "room_name": "private_room"
}

{
  "cmd": "s.communication.join_room",
  "result": "failure",
  "reason": "Inadequate permissions"
}
```

### TODO: `c.communication.leave_room`
* room_name :: string

#### Success response
Success is assumed, no response is sent

#### Example input/output
```json
{
  "cmd": "c.communication.leave_room",
  "room_name": "main"
}
```

### TODO: `c.communication.list_members`
* room_name :: string

#### Success response
* member_ids :: List (userid)

#### Example input/output
```json
{
  "cmd": "c.communication.list_members",
  "room_name": "main"
}

{
  "cmd": "s.communication.list_members",
  "member_ids": [1, 2, 3]
}
```


### TODO: `c.communication.room_message`
* room_name :: string
* message :: string

#### Success response
This command has no response expected. Though you should receive a `s.communication.room_message` from yourself (as will everybody else in the room).

#### Example input/output
```json
{
  "cmd": "c.communication.room_message",
  "room_name": "main",
  "message": "hello room!"
}
```

### TODO: `s.communication.room_message`
Sent when a new message is sent to a room.

* room_name :: string
* message :: string
* sender_id :: userid

#### Example input/output
```json
{
  "cmd": "s.communication.room_message",
  "room_name": "main",
  "message": "hello room!",
  "sender_id": 123
}
```

### TODO: `c.communication.send_direct_message`
* recipient_id :: userid
* message :: string

#### Success response
* result :: "success"

#### Failure response
* result :: "failure"
* reason :: string

#### Example input/output
```json
{
  "cmd": "c.communication.send_direct_message",
  "recipient_id": 789,
  "message": "hello person!"
}

{
  "cmd": "s.communication.send_direct_message",
  "result": "success"
}

{
  "cmd": "s.communication.send_direct_message",
  "result": "failure",
  "reason": "muted"
}
```

### TODO: `s.communication.received_direct_message`
* sender_id :: userid
* message :: string

#### Example
```json
{
  "cmd": "s.communication.received_direct_message",
  "sender_id": 123,
  "message": "hello person!"
}
```


