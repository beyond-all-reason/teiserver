### `c.client.list_clients_from_ids`
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