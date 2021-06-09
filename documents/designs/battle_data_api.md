## Description
An API for uploading data about battles fought to Teiserver.

## API Routes
### POST /teiserver/api/auth -- Authorises your user
**email:** the email of your account
**password:** the password of your account for authorisation
```
{
  "user": {
    "email": "my_email@email.com",
    "password": "Hunter2"
  }
}
```

**Expected response**
```
{
  "result": "success",
  "token": "..."
}
```

**Failure response**
```
{
  "result": "failure",
  "reason": "auth error"
}
```

### POST /teiserver/api/battles -- Uploads a battle
**Battle** the battle being uploaded
````
{
  "outcome": "completed",
  "players": [1,2,3],
  "spectators": [4,5,6],
  "team_count": 2,
  "map": "ccr"
}
```
