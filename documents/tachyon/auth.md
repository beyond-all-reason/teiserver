### `c.auth.get_token`
Given the correct email and password combination the server will send back a token that can be used to login as that user. This command must be performed over a secure connection, if it is attempted over an insecure connection the server will send back an error. If the password and email do not match a failure result is returned. Only email or name is required; if both then email will be used.

* email :: string
* name :: string
* password :: string

#### Response
* token :: string

#### Example input/output
```
{
  "cmd": "c.auth.get_token",
  "email": "email@email.com",
  "password": "*********"
}

{
  "cmd": "s.auth.get_token",
  "outcome": "success",
  "token": "long-string-of-digits-here"
}

{
  "cmd": "s.auth.get_token",
  "outcome": "failure",
  "reason": "reason for failure"
}
```

### `c.auth.login`
* token :: string

#### Response
* result :: Success | Failure
* user :: User

#### Example input/output
```
{
  "cmd": "c.auth.login",
  "token": "long-string-of-digits-here"
}

{
  "cmd": "s.auth.login",
  "result": "success",
  "user": User
}

{
  "cmd": "s.auth.login",
  "result": "failure",
  "reason": "Invalid token"
}
```
