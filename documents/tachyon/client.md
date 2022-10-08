### c.client.list_clients_from_ids
Given a list of ids, return information about the relevant clients

#### Arguments
`id_list` - list (User.id)

#### Response
* clients :: List (Client)

#### Example input/output
```json
{
  "cmd": "c.client.list_clients_from_ids",
  "id_list": [1, 2, 3]
}

{
  "cmd": "s.client.client_list",
  "clients": [
    Client,
    Client,
    Client
  ]
}
```


### s.client.connected
```json
{
  "cmd": "s.client.connected",
  "userid": 123
}
```

### s.client.disconnected
```json
{
  "cmd": "s.client.disconnected",
  "userid": 123
}
```

### s.client.added_to_party
```json
{
  "cmd": "s.client.added_to_party",
  "userid": 123,
  "party_id": "abc"
}
```

### s.client.left_party
```json
{
  "cmd": "s.client.left_party",
  "userid": 123,
  "party_id": "abc"
}
```


### s.client.added_to_lobby
```json
{
  "cmd": "s.client.added_to_lobby",
  "userid": 123,
  "lobby_id": "abc"
}
```

### s.client.left_lobby
```json
{
  "cmd": "s.client.left_lobby",
  "userid": 123,
  "lobby_id": "abc"
}
```
