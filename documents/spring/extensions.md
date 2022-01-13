### Spring protocol extensions
Teiserver implements a collection of additional commands beyond the spring protocol.

#### Differences
All extended commands have a namespaced structure and make use of tabs to separate arguments like so. They still make use of a space to separate the command from the first argument to aid in compatibility. This applies to responses too, the new `NO` response will use a tab to separate the command from the reason.
```
Command Arg1[tab]Arg2[tab]Arg3
```

#### `c.user.get_token_by_email email password`
Given the correct email and password combination the server will send back a token that can be used to login as that user. This makes use of the site password as opposed to the md5'd uberserver password used with the normal spring `LOGIN` command. This command must be performed over a TLS connection, if it is attempted over a non-secure connection the server will send back an error.
```
c.user.get_token_by_email email password
s.user.user_token email token
NO cmd=c.user.get_token invalid credentials
NO cmd=c.user.get_token cannot get token over insecure connection
```
This token should be stored and used to perform logins. Getting the token does not perform the login.

#### `c.user.get_token_by_name name password`
Identical to the above except instead of looking up the user by email it looks them up by name. This is to allow lobbies to store their user credentials as username or as email as they prefer.

#### `c.user.login token lobby flags`
A more secure way of logging in. If the login succeeds then the standard login process is followed. If the login fails then a standard `DENIED` response is sent. Lobby should be a string of the lobby name as with Spring and flags should be a list of key/values of the format `key=value` separated by spaces. The flags are currently not used for anything but there is an expectation they could be (e.g. compatibility flags).
```
c.user.login token my_lobby key=value key2=value
ACCEPTED user_name
DENIED token_login_failed
```

#### `c.moderation.report_user`
Adds a report of bad behaviour for the user. Location type should be something like "lobby", "battle" to give context to where the report happened. Location ID should be the specific numerical instance of that location. As chat rooms currently use names if you want to submit a report for a chat room the advised format is "chat:room_name" or just "chat". If you do not have a location_id then instead put "nil".
```
c.moderation.report_user target_name location_type location_id reason
c.moderation.report_user user123 lobby 5 reason for report
c.moderation.report_user user123 chat_room nil reason for report
OK
NO cmd=c.moderation.report_user reason_for_failure
```

#### `c.battles.list_ids`
Sends a list of battle ids separated by tabs:
```
c.battles.list_ids
s.battles.id_list 1 2 3
```

#### `s.battle.update_lobby_title lobby_id lobby.name`
Indicates a lobby has a new title.
```
s.battle.update_lobby_title 123 My new and fancy name
```

