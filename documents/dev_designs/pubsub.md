Teiserver makes use of the Phoenix pubsub. This document is designed to list the different channels and how they are used.

Anything prefixed with "legacy" is something only present because of the nature of the spring protocol and is going to be removed as soon as we're able to.
Anything prefixed with "teiserver" is something added after the spring protocol was implemented and follows better practices with clearer documentation.

Teiserver channels always send a map as the object and include the channel name (as a string) under the `channel` key.

## Server
#### teiserver_server
Used for sending out global messages about server events.
```elixir
%{
  event: :stopping,
  node: node
}

%{
  event: :started,
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

#### lobby_policy_internal:#{lobby_policy_id}
Used for internal communication around lobby_policies where something needs to be seen by all processes. These will all originate from the organiser.
```elixir
# Used to request a status update from all the agent nodes
%{
  event: :request_status_update
}

# Used to request a status update from all the agent nodes
%{
  event: :updated_policy,
  new_policy: LobbyPolicy
}

# Used to tell all bots of that policy to disconnect
%{
  event: :disconnect
}
```

#### lobby_policy_updates:#{lobby_policy_id}
Used by the bots to send updates to anything listening for them (organiser and liveviews).
```elixir
%{
  event: :disconnect
}
```

#### teiserver_public_stats
Similar to the `teiserver_telemetry` channel but specifically limited to be public info.
```elixir
%{
  user_count: integer,
  player_count: integer,
  lobby_count: integer,
  in_progress_lobby_count: integer
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

#### global_match_updates
Used to communicate information to everybody regarding matches.
```elixir
%{
  event: :match_completed,
  match_id: match_id
}
```

## Lobbies
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

# Users (change to clients?)
%{
  event: :add_user,
  lobby_id: lobby_id,
  client: client
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

#### teiserver_liveview_client:#{client_id}
Updates for clients using the liveview to help prevent doubling up on certain other ones.
```elixir
# Lobby
%{
  event: :joined_lobby,
  lobby_id: lobby_id
}

%{
  event: :left_lobby,
  lobby_id: lobby_id
}
```

#### teiserver_lobby_chat:#{battle_lobby_id}
Information specific to the chat in a battle lobby, state changes to the battle are not sent via this channel.
```elixir
%{
  event: :say,
  lobby_id: lobby_id,
  userid: user_id,
  message: message
}

%{
  event: :announce,
  lobby_id: lobby_id,
  userid: user_id,
  message: message
}
```

#### teiserver_liveview_lobby_index_updates
Sent out to inform there is fresh data available in the lobby index throttle.

```elixir
%{
  event: :updated_data
}
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
%{
  event: :login
  userid: userid
}

%{
  event: :disconnect
  userid: userid,
  reason: String
}

```

#### teiserver_client_messages:#{userid}
This is the channel for sending messages to the client. It allows the client on the web and lobby application to receive messages.
```elixir
# Connected/Disconnected, useful for the site
%{
  event: :connected
}

%{
  event: :disconnected
}

%{
  event: :client_updated,
  new_status: map()
}

# Matchmaking
%{
  event: :matchmaking,
  sub_event: :joined_queue,
  queue_id: queue_id
}

%{
  event: :matchmaking,
  sub_event: :left_queue,
  queue_id: queue_id
}

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

# Used to say you (or someone in your party) declined
# the match and thus you are in no queues any more
%{
  event: :matchmaking,
  sub_event: :match_declined,
  queue_id: queue_id,
  match_id: match_id
}

# Used to say your match was created and (in theory) started
# and as a result you are not in any queues
%{
  event: :matchmaking,
  sub_event: :match_created,
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
  event: :added_to_lobby,
  lobby_id: lobby_id,
  script_password: string
}

%{
  event: :force_join_lobby,
  lobby_id: lobby_id,
  script_password: string
}

# Parties
%{
  event: :added_to_party,
  party_id: party_id
}

%{
  event: :party_invite,
  party_id: party_id
}

%{
  event: :left_party,
  party_id: party_id
}
```

#### teiserver_client_watch:#{userid}
Gives information about the activities of a client without containing anything personal. Used for allowing friends to be updated about the activities of friends.
```elixir
# In/Out
%{
  event: :connected
}

%{
  event: :disconnected
}

# Lobbies 
%{
  event: :added_to_lobby,
  lobby_id: lobby_id,
}

%{
  event: :left_lobby,
  lobby_id: lobby_id
}

# Parties
%{
  event: :added_to_party,
  party_id: party_id
}

%{
  event: :left_party,
  party_id: party_id
}
```

#### client_application:#{userid}
Designed for lobby applications to display/perform various actions as opposed to internal agent clients or any web interfaces
```elixir
  %{
    event: :ring,
    userid: userid,
    ringer_id: ringer_id
  }
```

#### teiserver_user_updates:#{userid}
Information pertinent to a specific user
```elixir
  %{
    event: :update_report,
    userid: userid,
    report_id: report_id
  }

  %{
    event: :friend_request,
    userid: userid,
    requester_id: userid
  }

  %{
    event: :friend_added,
    userid: userid,
    friend_id: userid
  }

  %{
    event: :friend_removed,
    userid: userid,
    friend_id: userid
  }
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
  event: :message,
  party_id: party_id,
  sender_id: userid,
  message: string
}
```


## Chat
#### room:#{room_name}
All updates about the room and content for the room. Likely to be kept as is and renamed as a teiserver channel due to its nature.

### Matchmaking
#### teiserver_global_matchmaking
Used to communicate to all wait servers so groups can be added/removed from queues correctly.
```elixir
# A match has been found, stop these groups searching for now
%{
  event: :pause_search
  groups: [group_id]
}

# Match failed to start, these groups are to resume searching
%{
  event: :resume_search
  groups: [group_id]
}

# This can fire for both a match starting and a match being declined
%{
  event: :cancel_search
  groups: [group_id]
}
```

#### teiserver_queue:#{queue_id}
Sent from the queue wait server to update regarding it's status
Valid events
```elixir
%{
  event: :queue_periodic_update,
  queue_id: queue_id,
  buckets: map(),
  groups_map: map()
}

%{
  event: :queue_add_group,
  queue_id: queue_id
  group_id: group_id
}

%{
  event: :queue_remove_group,
  queue_id: queue_id
  group_id: group_id
}


%{
  event: :match_attempt,
  queue_id: queue_id,
  match_id: match_id
}

%{
  event: :match_made,
  queue_id: queue_id,
  lobby_id: lobby_id
}
```

#### teiserver_all_queues
Data for those watching all queues at the same time
Valid events
```elixir
  %{
    event: :all_queues_periodic_update,
    queue_id: queue_id,
    group_count: integer,
    mean_wait_time: number
  }
```

## Moderation
#### global_moderation
```elixir
%{
  event: :new_report,
  report: Report
}

%{
  event: :new_action,
  action: Action
}

%{
  event: :updated_action,
  action: Action
}

%{
  event: :new_proposal,
  proposal: Proposal
}

%{
  event: :updated_proposal,
  proposal: Proposal
}

%{
  event: :new_ban,
  ban: Ban
}
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
