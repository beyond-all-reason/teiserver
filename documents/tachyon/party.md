### `c.party.create`
Creates a new party, if you are part of an existing party it will remove you from that party. You will be the leader of the new party and the sole member.

#### Success response
* party :: Party

#### Example input/output
```json
{
  "cmd": "c.party.create"
}

{
  "cmd": "s.party.create",
  "party": {
    "id": "1d5366a6-f55d-11ec-b427-f02f74dbae33",
    "leader": 123,
    "members": [123],
    "pending_invites": []
  }
}
```

### `c.party.info`
Returns info about a given party. If you are not a member of the party then pending invites will always be missing. If the party does not exist, it will return null for the party.

#### Example input/output
```json
{
  "cmd": "c.party.info",
  "party_id": "1d5366a6-f55d-11ec-b427-f02f74dbae33"
}

{
  "cmd": "s.party.info",
  "party": {
    "id": "1d5366a6-f55d-11ec-b427-f02f74dbae33",
    "leader": 123,
    "members": [123],
    "pending_invites": []
  }
}

{
  "cmd": "s.party.info",
  "party": null
}
```

### `s.party.updated`
Sends a new party state. Fires upon any updates to the party such as change of invites, membership or leadership. It will contain a the changed values within the party. If a value is absent it means it was not changed.

#### Example output
```json
{
  "cmd": "s.party.updated",
  "party_id": "1d5366a6-f55d-11ec-b427-f02f74dbae33",
  "new_values": {
    "leader": 123,
    "members": [123, 124],
    "pending_invites": [125]
  }
}
```

### `c.party.invite`
Invites a user to the party; if successful you will get a `s.party.updated` sent as a response as the party state updates.

#### Example input
```json
{
  "cmd": "c.party.invite",
  "userid": 123
}
```

### `s.party.invite`
Server message telling a user they have been invited to a party, it will contain full party info (including pending invites) and the user who invited you.

#### Example input
```json
{
  "cmd": "s.party.invite",
  "invited_by": 123,
  "party": {
    "id": "1d5366a6-f55d-11ec-b427-f02f74dbae33",
    "leader": 123,
    "members": [123, 124],
    "pending_invites": [125]
  }
}
```

### `c.party.accept`
Accept an invite to a party, this will result in you being added to the party as a member and leaving your existing party if you are a member of one. As the party state will change you will be sent a `s.party.updated` response. If unsuccessful you will receive a failure response.

#### Example input/output
```json
{
  "cmd": "c.party.accept",
  "party_id": "1d5366a6-f55d-11ec-b427-f02f74dbae33"
}

// Success
{
  "cmd": "s.party.info",
  "party": Party
}

// Failure
{
  "cmd": "s.party.accept",
  "party_id": "1d5366a6-f55d-11ec-b427-f02f74dbae33",
  "result": "failure"
}
```

### `c.party.decline`
Reject the invitation to the party, result in you being removed from the party invite list.

#### Example input
```json
{
  "cmd": "c.party.decline",
  "party_id": "1d5366a6-f55d-11ec-b427-f02f74dbae33"
}
```

### `c.party.kick`
Kicks a member of the party out, only useable by the party leader. If successful you will receive a `s.party.kicked` message (along with everybody else in the party).

#### Example input/output
```json
{
  "cmd": "c.party.kick",
  "userid": 124
}

{
  "cmd": "s.party.kicked",
  "user_id": 124,
  "kicked_by": 123
}
```

### `s.party.kicked`
Sent when a member of the party is kicked, this is sent in place of the normal `s.party.updated` which would be sent on party change.

#### Example output
```json
{
  "cmd": "s.party.kicked",
  "user_id": 124,
  "kicked_by": 123
}
```

### `c.party.new_leader`
Used by the leader of the party to assign a new leader. Does not change the party membership but will prompt a `s.party.updated` message.

#### Example input
```json
{
  "cmd": "c.party.new_leader",
  "user_id": 124
}
```

### `c.party.leave`
Remove yourself from the party. If you are the leader of the party it will assign a the longest serving member of the party to be the new leader. Remaining party members will receive a `s.party.updated` message.

#### Example input
```json
{
  "cmd": "c.party.leave"
}
```

### `c.party.message`
Send a message to the party chat.

#### Example input
```json
{
  "cmd": "c.party.message",
  "message": "My fancy message here"
}
```

### `s.party.message`
Server informing you of a message in the party chat.

#### Example output
```json
{
  "cmd": "s.party.message",
  "user_id": 124,
  "message": "My fancy message here"
}
```
