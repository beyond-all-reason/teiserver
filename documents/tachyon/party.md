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
    "leader": 123,
    "members": [123],
    "pending_invites": []
  }
}
```

### `c.party.info`
Returns info about a given party

### `s.party.updated`
Sends a new party state. Fires upon any updates to the party such as change of invites, membership or leadership.

### `c.party.invite`
Invites a user to the party.

### `s.party.invite`
Server message telling a user they have been invited to a party

### `c.party.accept`
Accept an invite to a party, this will result in you being added to the party as a member and leaving your existing party if you are a member of one.

### `c.party.decline`
Reject the invitation to the party, result in you being removed from the party invite list.

### `c.party.kick`
Kicks a member of the party out, only useable by the party leader.

### `c.party.new_leader`
Used by the leader of the party to assign a new leader. Does not change the party membership.

### `c.party.leave`
Remove yourself from the party. If you are the leader of the party it will assign a the longest serving member of the party to be the new leader.

### `c.party.message`
Send a message to the party chat.

### `s.party.message`
Server informing you of a message in the party chat.
