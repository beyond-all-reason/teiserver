Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

Teiserver channels always send a map as the object and include the channel name (as a string) under the `channel` key.

## Server
#### teiserver_server
Used for sending out global messages about server events.
```elixir
%{
  event: "stop",
  node: node
}
```

#### teiserver_telemetry
Used for broadcasting internal telemetry for consumers (such as admin dashboard)
```elixir
%{
  data: %{
    client: map(),
    battle: map()
  }
}
```

#### teiserver_telemetry_client_events
Used for broadcasting specific client telemetry events as defined in Teiserver.Telemetry. Does not broadcast anonymous events.
```elixir
%{
  userid: userid,
  event_type_name: string,
  event_value: any
}
```

#### teiserver_telemetry_client_properties
Used for broadcasting specific client telemetry property updates as defined in Teiserver.Telemetry. Does not broadcast anonymous property updates.
```elixir
%{
  userid: userid,
  property_name: string,
  property_value: any
}
```

#### teiserver_telemetry_server_events
Used for broadcasting server event telemetry
```elixir
%{
  userid: userid,
  event_type_name: event_type_name,
  value: value
}
```

## Battles
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

#### teiserver_global_match_updates

```elixir
  {:global_match_updates, :match_completed, match_id}
```

## Lobbies
#### teiserver_lobby_host_message:#{battle_lobby_id}
Messages intended for the host of a given lobby. This saves a call for the client pid and also allows debugging tools to hook into the messages if needed.
Valid events:
```elixir
  # Structure
  {:lobby_host_message, _action, lobby_id, _data}

  # Examples
  {:lobby_host_message, :user_requests_to_join, lobby_id, {userid, script_password}}
```

#### teiserver_lobby_updates:#{battle_lobby_id}
Information affecting only those in this given lobby. Chat is not sent via this channel.
Valid events:
```elixir
  # Structure
  {:lobby_update, _action, lobby_id, _data}

  # BattleLobby
  {:lobby_update, :updated, lobby_id, update_reason}
  {:lobby_update, :closed, lobby_id, reason}
  {:lobby_update, :add_bot, lobby_id, Bot}
  {:lobby_update, :update_bot, lobby_id, Bot}
  {:lobby_update, :remove_bot, lobby_id, botname}
  {:lobby_update, :add_user, lobby_id, userid}
  {:lobby_update, :remove_user, lobby_id, userid}
  {:lobby_update, :kick_user, lobby_id, userid}
  
  {:lobby_update, :set_modoption, lobby_id, {key, value}}
  {:lobby_update, :set_modoptions, lobby_id, options}
  {:lobby_update, :remove_modoptions, lobby_id, keys}

  # Partial lobby updates
  {:lobby_update, :update_value, lobby_id, {key, value}}

  # Client
  {:lobby_update, :updated_client_battlestatus, lobby_id, {Client, reason}}
```

#### teiserver_lobby_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle are not sent via this channel.
Valid events:
```elixir
  # Structure
  {:lobby_chat, _action, lobby_id, userid, _data}

  # Chatting
  {:lobby_chat, :say, lobby_id, userid, msg}
  {:lobby_chat, :announce, lobby_id, userid, msg}
```

#### teiserver_liveview_lobby_updates:#{battle_lobby_id}
These are updates sent from the LiveBattle genservers (used to throttle/batch messages sent to the liveviews).
```elixir
  # Coordinator
  {:liveview_lobby_update, :consul_server_updated, lobby_id, reason}
```

#### teiserver_liveview_lobby_chat:#{battle_lobby_id}
Updates specifically for liveview chat interfaces, due to the way messages are persisted from matchmonitor server.
```elixir
  # Coordinator
  {:liveview_lobby_chat, :say, lobby_id, reason}
```

### User/Client
#### teiserver_client_inout
A message every time a user logs in or logs out. Unlike legacy all_user_updates it does not give any status updates.
```elixir
  {:client_inout, :login, userid}
  {:client_inout, :disconnect, userid, reason}
```

#### teiserver_client_messages:#{userid}
This is the channel for sending messages to the client. It allows the client on the web and lobby application to receive messages.
```elixir
# Matchmaking
%{
  event: :matchmaking,
  sub_event: :match_ready,
  queue_id: queue_id,
  match_id: match_id
}

%{
  event: :matchmaking,
  sub_event: :join_lobby,
  lobby_id: lobby_id
}

%{
  event: :matchmaking,
  sub_event: :match_cancelled,
  queue_id: queue_id,
  match_id: match_id
}

%{
  event: :matchmaking,
  sub_event: :match_declined,
  queue_id: queue_id,
  match_id: match_id
}

# Messaging
%{
  event: :received_direct_message,
  sender_id: userid,
  message_content: list(string)
}

%{
  event: :lobby_direct_say,
  sender_id: userid,
  message_content: list(string)
}

%{
  event: :lobby_direct_announce,
  sender_id: userid,
  message_content: list(string)
}

# Server initiated actions related to the lobby
%{
  event: :join_lobby_request_response,
  lobby_id: lobby_id,
  response: :accept | :deny,
  reason: string
}

%{
  event: :force_join_lobby,
  lobby_id: lobby_id,
  script_password: string
}

# Parties
%{
  event: :party_invite,
  party_id: party_id
}
```

#### teiserver_client_action_updates:#{userid}
Informs about actions performed by a specific client
Aside from connect/disconnect there should always be the structure of `{:client_action, :join_queue, userid, data}`
```elixir
  {:client_action, :client_connect, userid}
  {:client_action, :client_disconnect, userid}

  {:client_action, :join_queue, userid, queue_id}
  {:client_action, :leave_queue, userid, queue_id}

  {:client_action, :join_lobby, userid, lobby_id}
  {:client_action, :leave_lobby, userid, lobby_id}
```

#### teiserver_client_application:#{userid}
Designed for lobby applications to display/perform various actions as opposed to internal agent clients or any web interfaces
```elixir
  {:teiserver_client_application, :ring, userid, ringer_id}
```

#### teiserver_user_updates:#{userid}
Information pertinent to a specific user
```elixir
  # {:user_update, ?update_type?, userid, ?data?}

  {:user_update, :update_report, user.id, report.id}
```

## Parties
#### teiserver_party:#{party_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
%{
  event: :updated_values,
  party_id: party_id,
  new_values: map
}

%{
  event: :closed,
  party_id: party_id,
  reason: string
}

%{
  event: :chat,
  party_id: party_id,
  senderid: userid,
  message: string
}
```


## Chat
#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

### Matchmaking
#### teiserver_queue_wait:#{queue_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
  {:queue_wait, :queue_add_user, queue_id, userid}
  {:queue_wait, :queue_remove_user, queue_id, userid}
  
  {:queue_wait, :queue_add_party, queue_id, party_id}
  {:queue_wait, :queue_remove_party, queue_id, party_id}

  {:queue_match, :match_attempt, queue_id, match_id}
  {:queue_match, :match_made, queue_id, lobby_id}
```

#### teiserver_queue_all_queues
Data for those watching all queues at the same time
Valid events
```elixir
  {:queue_periodic_update, queue_id, queue_size, mean_wait_time}
```


## Central
#### account_hooks
Used for hooking into account related activities such as updating users.

Valid events
```elixir
  {:account_hooks, :create_user, user, :create}
  {:account_hooks, :update_user, user, :update}

  {:account_hooks, :create_report, report}
  {:account_hooks, :update_report, report, :create | :respond | :update}
```

## Legacy
#### legacy_all_battle_updates
Information affecting all those not in a battle, such as a battle being created.

#### legacy_battle_updates:#{battle_lobby_id}
Information affecting only those in this given battle, such as a player joining.


#### legacy_all_user_updates
Information about all users, such as a user logging on/off

#### legacy_user_updates:#{userid}
Information about a specific user such as friend related stuff.

#### legacy_all_client_updates
Overlaps with `legacy_all_user_updates` due to blurring of user vs client domain.
