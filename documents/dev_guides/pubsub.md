Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

### Battles
#### legacy_all_battle_updates
Information affecting all those not in a battle, such as a battle being created.

#### legacy_battle_updates:#{battle_lobby_id}
Information affecting only those in this given battle, such as a player joining.

#### teiserver_global_battle_lobby_updates
Limited information pertaining to the creation/deletion of battles.
Data is always of the format: `{:event, battle_lobby_id}`
Valid events: `battle_lobby_opened`, `battle_lobby_closed`

#### teiserver_battle_lobby_updates:#{battle_lobby_id}
Information affecting only those in this given battle, such as a player joining. Identical to the above but specifically different to prevent spring systems getting double-pinged.
Valid events:
```
  # BattleLobby
  {:battle_lobby_updated, lobby_id, data, update_reason}
  {:battle_lobby_closed, lobby_id}
  {:add_bot_to_battle_lobby, lobby_id, bot}
  {:update_bot_in_battle_lobby, lobby_id, botname, new_bot}
  {:remove_bot_from_battle_lobby, lobby_id, botname}
  {:add_user_to_battle_lobby, lobby_id, userid}
  {:remove_user_from_battle_lobby, lobby_id, userid}
  {:kick_user_from_battle_lobby, lobby_id, userid}
  
  # Coordinator
  {:consul_server_updated, state.battle_id, reason}

  # Client
  {:updated_client_status, client, reason} # Yes, that's the full client object
```

#### teiserver_battle_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle will never be in this channel.
Valid events:
```
  {:battle_lobby_say, lobby_id, userid, msg}
  {:battle_lobby_sayex, lobby_id, userid, msg}
```

#### live_battle_updates:#{battle_lobby_id}
In the process of being phased out with the introduction of teiserver_liveview_battle_lobby_updates

#### teiserver_liveview_battle_lobby_updates:#{battle_lobby_id}
These are updates sent from the LiveBattle genservers (used to throttle/batch messages sent to the liveviews).

### User/Client
#### legacy_all_user_updates
Information about all users, such as a user logging on/off

#### legacy_user_updates:#{userid}
Information about a specific user such as friend related stuff.

#### legacy_all_client_updates
Overlaps with `legacy_all_user_updates` due to blurring of user vs client domain.

#### teiserver_liveview_client_index_updates
These are updates sent from the ClientIndex genserver (used to throttle/batch messages sent to the liveviews).

### Chat
#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

### Matchmaking
#### teiserver_queue:#{queue_id}
Sent from the queue server to update regarding it's status
Valid events
```
{:add_player, userid}
{:remove_player, userid}
```


### Dev mode
agent_updates