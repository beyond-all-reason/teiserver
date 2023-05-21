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

#### client_inout
A message every time a user logs in or logs out. Unlike legacy all_user_updates it does not give any status updates.
```elixir
%{
  event: :login
  userid: userid
  client: client
}

%{
  event: :disconnect
  userid: userid,
  reason: String
}
```

#### teiserver_global_user_updates
Used to provide global info on all users, intended only to be used while we transition the legacy protocol.
```elixir
%{
  event: :joined_lobby,
  client: client,
  lobby_id: lobby_id,
  script_password: script_password
}

%{
  event: :left_lobby,
  client: client,
  lobby_id: lobby_id
}

%{
  event: :kicked_from_lobby,
  client: client,
  lobby_id: lobby_id
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