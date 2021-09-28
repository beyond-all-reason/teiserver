Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

### Server
#### teiserver_server
Used for sending out global messages about server events
```
  {:server_event, :server_restart}
```

### Battles
#### legacy_all_battle_updates
Information affecting all those not in a battle, such as a battle being created.

#### legacy_battle_updates:#{battle_lobby_id}
Information affecting only those in this given battle, such as a player joining.

#### teiserver_global_battle_lobby_updates
Limited information pertaining to the creation/deletion of battles.
```
  {:battle_lobby_opened, lobby_id}
  {:battle_lobby_closed, lobby_id}
```

#### teiserver_lobby_updates:#{battle_lobby_id}
Information affecting only those in this given battle. Chat is not sent via this channel.
Valid events:
```
  # BattleLobby
  {:lobby_update, :updated, lobby_id, update_reason}
  {:lobby_update, :closed, lobby_id, reason}
  {:lobby_update, :add_bot, lobby_id, botname}
  {:lobby_update, :update_bot, lobby_id, botname}
  {:lobby_update, :remove_bot, lobby_id, botname}
  {:lobby_update, :add_user, lobby_id, userid}
  {:lobby_update, :remove_user, lobby_id, userid}
  {:lobby_update, :kick_user, lobby_id, userid}
  
  # Coordinator
  {:lobby_update, :consul_server_updated, lobby_id, reason}

  # Client
  {:lobby_update, :updated_client_status, lobby_id, {userid, reason}}
```

#### teiserver_lobby_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle will never be in this channel.
Valid events:
```
  {:lobby_chat, :say, lobby_id, userid, msg}
  {:lobby_chat, :sayex, lobby_id, userid, msg}
```

#### live_battle_updates:#{battle_lobby_id}
In the process of being phased out with the introduction of teiserver_liveview_lobby_updates

#### teiserver_liveview_lobby_updates:#{battle_lobby_id}
These are updates sent from the LiveBattle genservers (used to throttle/batch messages sent to the liveviews).

### User/Client
#### legacy_all_user_updates
Information about all users, such as a user logging on/off

#### legacy_user_updates:#{userid}
Information about a specific user such as friend related stuff.

#### legacy_all_client_updates
Overlaps with `legacy_all_user_updates` due to blurring of user vs client domain.

#### teiserver_client_inout
A message every time a user logs in or logs out. Unlike legacy all_user_updates it does not give any status updates.
```
  {:client_inout, :login, userid}
  {:client_inout, :disconnect, userid, reason}
```

#### teiserver_liveview_client_index_updates
These are updates sent from the ClientIndex genserver (used to throttle/batch messages sent to the liveviews).
Valid events
```
  {:client_index_throttle, new_clients_map, removed_clients}
```

### teiserver_client_messages:#{userid}
This is the channel for sending messages to the client. It allows the client on the web and lobby application to receive messages.
General structure should be: `{:client_message, :topic, userid, data}` to allow for easy matching and discarding as new items are added to the list
```
  {:client_message, :matchmaking, userid, {:match_ready, state.id}}
  {:client_message, :matchmaking, userid, {:join_lobby, state.id}}

  {:client_message, :lobby, userid, {:join_lobby, lobby_id}}
  {:client_message, :lobby, userid, {:leave_lobby, lobby_id}}
```

### teiserver_client_action_updates:#{userid}
Information actions taken by a specific user
Aside from connect/disconnect there should always be the structure of `{:client_action, :join_queue, userid, data}`
```
  {:client_action, :client_connect, userid}
  {:client_action, :client_disconnect, userid}

  {:client_action, :join_queue, userid, queue_id}
  {:client_action, :leave_queue, userid, queue_id}

  {:client_action, :join_lobby, userid, lobby_id}
  {:client_action, :leave_lobby, userid, lobby_id}
```


### Chat
#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

### Matchmaking
#### teiserver_queue:#{queue_id}
Sent from the queue server to update regarding it's status
Valid events
```
  {:queue_add_player, queue_id, userid}
  {:queue_remove_player, queue_id, userid}
  {:match_made, queue_id, lobby_id}
```

#### teiserver_queue_all_queues
Data for those watching all queues at the same time
Valid events
```
  {:queue_periodic_update, queue_id, queue_size, last_wait_time}
```


### Dev mode
agent_updates