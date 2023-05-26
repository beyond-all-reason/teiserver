#### teiserver_global_lobby_updates
Limited information pertaining to the creation/deletion of battle lobbies.
```elixir
%{
  event: :opened,
  lobby: lobby,
}

%{
  event: :closed,
  lobby_id: lobby_id
}

%{
  event: :updated_values,
  lobby_id: lobby_id,
  new_values: map
}
```

#### global_match_updates
Used to communicate information to everybody regarding matches.
```elixir
%{
  event: :match_completed,
  match_id: match_id
}
```

#### teiserver_lobby_host_message:#{battle_lobby_id}
Messages intended for the host of a given lobby. This saves a call for the client pid and also allows debugging tools to hook into the messages if needed.
Valid events:
```elixir
%{
  event: :user_requests_to_join,
  lobby_id: lobby_id,
  userid: userid,
  script_password: string
}
```

#### teiserver_lobby_updates:#{battle_lobby_id}
Information affecting only those in this given lobby. Chat is not sent via this channel.
Valid events:
```elixir
# To be removed
%{
  event: :updated,
  lobby_id: lobby_id,
  reason: reason
}

# BattleLobby
%{
  event: :closed,
  lobby_id: lobby_id,
  reason: reason
}

# Bots
%{
  event: :add_bot,
  lobby_id: lobby_id,
  bot: bot
}

%{
  event: :update_bot,
  lobby_id: lobby_id,
  bot: bot
}

%{
  event: :remove_bot,
  lobby_id: lobby_id,
  bot: botname
}

%{
  event: :add_user,
  lobby_id: lobby_id,
  client: client
  script_password: script_password
}

%{
  event: :remove_user,
  lobby_id: lobby_id,
  client: client
}

%{
  event: :kick_user,
  lobby_id: lobby_id,
  client: client
}

# Modoptions
%{
  event: :set_modoptions,
  lobby_id: lobby_id,
  options: map()
}

%{
  event: :remove_modoptions,
  lobby_id: lobby_id,
  keys: keys
}

# Start areas
%{
  event: :add_start_area,
  lobby_id: lobby_id,
  area_id: integer(),
  area: map()
}

%{
  event: :remove_start_area,
  lobby_id: lobby_id,
  area_id: integer()
}

# Partial lobby updates
%{
  event: :update_values,
  lobby_id: lobby_id,
  changes: map()
}

# Client
%{
  event: :updated_client_battlestatus,
  lobby_id: lobby_id,
  client: client,
  reason: reason
}
  
# Queue
%{
  event: :updated_client_battlestatus,
  lobby_id: lobby_id,
  id_list: id_list
}
```