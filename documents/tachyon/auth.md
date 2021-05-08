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
  "result": "success",
  "token": "long-string-of-digits-here"
}

{
  "cmd": "s.auth.get_token",
  "result": "failure",
  "reason": "reason for failure"
}
```

### `c.auth.login`
Performs user authentication via a token obtained from `c.auth.token`.
* token :: string
* lobby_name :: string
* lobby_version :: string

#### Response
* result :: Success | Unverified | Failure
* user :: User

#### Example input/output
```
{
  "cmd": "c.auth.login",
  "lobby_name": "Skylobby",
  "lobby_version": "1.3.2"
  "token": "long-string-of-digits-here"
}

{
  "cmd": "s.auth.login",
  "result": "success",
  "user": User
}

{
  "cmd": "s.auth.login",
  "result": "unverified",
  "agreement": "Multiline\nText\nBlob"
}

{
  "cmd": "s.auth.login",
  "result": "failure",
  "reason": "Invalid token"
}
```

### `c.auth.verify`
Confirms the accuracy of the user email address. Once successful the user will be marked as verified and the user logged in.
* token :: string
* verification_code :: string

#### Response
* result :: Success | Failure
* user :: User

#### Example input/output
```
{
  "cmd": "c.auth.verify",
  "token": "long-string-of-digits-here",
  "code": "123456"
}

{
  "cmd": "s.auth.verify",
  "result": "success",
  "user": User
}

{
  "cmd": "s.auth.verify",
  "result": "failure",
  "reason": "bad code"
}
```
