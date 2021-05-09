### `c.users.query`
* query :: Query

#### Queryable fields
`name` - String
`clan_id` - Clan.id

#### Response
* user_list :: List (User)

#### Example input/output
```
{
  "cmd": "c.users.query",
  "query": Query
}

{
  "cmd": "s.users.query",
  "user_list": [
    User,
    User,
    User
  ]
}
```

#### Other users
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
