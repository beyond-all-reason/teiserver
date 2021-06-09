### Description
An API for uploading data about battles fought to Teiserver.

### API Routes
##### POST /teiserver/api/auth -- Authorises your user
**email:** the email of your account
**password:** the password of your account for authorisation
```
{
  "email": "my_email@email.com",
  "password": "Hunter2"
}
```

** Expected response
```
{
  "email": "my_email@email.com",
  "password": "Hunter2"
}
```

##### PUT /teiserver/api/battles -- Uploads a battle

````

```