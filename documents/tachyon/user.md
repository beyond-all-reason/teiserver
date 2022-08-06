### `c.user.list_users_from_ids`
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

### `c.user.list_friend_ids`
Returns a list of user ids of those on your friend list

#### Example input/output
```json
{
  "cmd": "c.user.list_friend_ids"
}

{
  "cmd": "s.user.list_friend_ids",
  "friend_id_list": [1, 2, 3]
}
```

### `c.user.list_friend_users_and_clients`
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

#### Friends
- List friends (query?)
- Add friend
- Remove friend

#### This user
- Get preference
- Get all preferences
- Set preference
- List preference keys
- List preference keys and descriptions
