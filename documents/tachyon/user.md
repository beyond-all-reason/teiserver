### `c.user.query`
* query :: Query

#### Queryable fields
`name` - String
`clan_id` - Clan.id
`id_list` - list (User.id)

#### Response
* user_list :: List (User)

#### Example input/output
```
{
  "cmd": "c.user.query",
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
```
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
