A set of channels specifically for sending information to liveview pages

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

#### teiserver_liveview_login_throttle
Updates specifically for the admin dashboard from the login throttle.
```elixir
  %{
    event: :tick,
    heartbeats: new_heartbeats,
    queues: new_queues,
    recent_logins: new_recent_logins,
    arrival_times: new_arrival_times
  }
  
  %{
    event: add_to_release_list,
    userid: userid
  }
```
