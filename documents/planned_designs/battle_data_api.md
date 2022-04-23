## Description
An API for uploading data about battles fought to Teiserver.

## API Routes
### POST /teiserver/api/auth -- Authorises your user
**email:** the email of your account
**password:** the password of your account for authorisation
```json
// curl -X POST $SERVER_ADDR/teiserver/api/auth -H "Content-Type: application/json" -d '{"user": {"email": "email@email", "password": "password1"}}'

// Example data
{
  "user": {
    "email": "my_email@email.com",
    "password": "Hunter2"
  }
}
```

**Expected response**
```json
{
  "result": "success",
  "token": "..."
}
```

**Failure response**
```json
{
  "result": "failure",
  "reason": "auth error"
}
```

### POST /teiserver/api/battles -- Uploads a battle
```
curl -X POST $SERVER_ADDR/teiserver/api/battle/create -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" -d '{--data goes here--}'

## Example data
{
  "outcome": "completed",
  -- other stuff here, just needs to be marked as completed --
}
```
