### c.user.list_users_from_ids
Returns a list of users as listed by the ids.

#### Arguments
`id_list` - list (User.id)

##### Optional
`include_clients` - Booalen - default false

#### Response
* users :: List (User)

#### Example input/output
```json
{
  "cmd": "c.user.list_users_from_ids",
  "id_list": [1, 2, 3],
  "include_clients": true
}

// Without clients
{
  "cmd": "s.user.user_list",
  "user_list": [
    User,
    User,
    User
  ]
}

// With clients
{
  "cmd": "s.user.user_list",
  "user_list": [
    User,
    User,
    User
  ],
  "client_list": [
    Client,
    Client,
    Client
  ]
}
```

### c.user.list_friend_ids
Returns a list of user ids of those on your friend list and any requests you have awaiting your approval.

#### Example input/output
```json
{
  "cmd": "c.user.list_friend_ids"
}

{
  "cmd": "s.user.list_friend_ids",
  "friend_id_list": [1, 2, 3],
  "request_id_list": [4, 5, 6]
}
```

### c.user.list_friend_users_and_clients
Returns a all users of your friends and clients of those that are logged in. Will specifically return information about the party of the clients as they are your friends.

#### Example input/output
```json
{
  "cmd": "c.user.list_friend_users_and_clients"
}

{
  "cmd": "s.user.list_friend_ids",
  "user_list": [
    User,
    User,
    User
  ],
  "client_list": [
    Client,
    Client,
    Client
  ]
}
```

#### Other user stuff
- Mute/unmute
- Add note

## Friends
### c.user.add_friend
Sends a friend request to a user.
```json
{
  "cmd": "c.user.add_friend",
  "user_id": userid
}
```

### s.user.friend_request
The server informing you of a new friend request.
```json
{
  "cmd": "s.user.friend_request",
  "user_id": userid
}
```

### c.user.rescind_friend_request
Rescinds your previously sent friend request.
```json
{
  "cmd": "c.user.rescind_friend_request",
  "user_id": userid
}
```

### c.user.accept_friend_request
Accepting a request to be friends. If it succeeds you should get a `s.user.new_friend` message.
```json
{
  "cmd": "c.user.accept_friend_request",
  "user_id": userid
}
```

### s.user.new_friend
The server informing you of a new friend.
```json
{
  "cmd": "s.user.new_friend",
  "user_id": userid
}
```

### c.user.reject_friend_request
Rejects the friend request, the other user is not notified of this.
```json
{
  "cmd": "s.user.reject_friend_request",
  "user_id": userid
}
```

### c.user.remove_friend
Removes someone as a friend, the other user is notified of this. You should receive a `s.user.friend_removed` response.
```json
{
  "cmd": "c.user.remove_friend",
  "user_id": userid
}
```

### s.user.friend_removed
Informing you a friend has been removed.
```json
{
  "cmd": "s.user.friend_removed",
  "user_id": userid
}
```
