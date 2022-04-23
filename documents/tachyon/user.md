### `c.user.list_users_from_ids`
Returns a list of users as listed by the ids.

#### Arguments
`id_list` - list (User.id)

#### Response
* users :: List (User)

#### Example input/output
```json
{
  "cmd": "c.user.list_users_from_ids",
  "query": Query
}

{
  "cmd": "s.user.query",
  "user_list": [
    User,
    User,
    User
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
